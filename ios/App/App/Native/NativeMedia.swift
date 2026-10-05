import SwiftUI
import AVFoundation
import Speech
import QuickLook
import EdizCore
import PhotosUI
import UniformTypeIdentifiers
import ImageIO
import NaturalLanguage
import MediaPlayer
import AVKit
import Accelerate

@MainActor enum NativeAudioSession {
    private static var owner:UUID?
    private static var stopOwner:(()->Void)?
    static func activate(_ id:UUID,category:AVAudioSession.Category,mode:AVAudioSession.Mode,onReplacement:(()->Void)?=nil) throws {
        if owner != id{let stop=stopOwner;owner=nil;stopOwner=nil;stop?()}
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(category,mode:mode,options:category == .record ? []:category == .playAndRecord ? [.defaultToSpeaker,.allowBluetoothHFP]:.duckOthers)
        try session.setActive(true);owner=id;stopOwner=onReplacement
    }
    static func release(_ id:UUID){guard owner==id else{return};owner=nil;stopOwner=nil;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
}
@MainActor enum NativeVoicePreferences {
    static let defaults:UserDefaults = {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"),let id=ProcessInfo.processInfo.environment["EDIZ_UI_TEST_ID"] {
            return UserDefaults(suiteName:"com.ediz.os.testvoice."+id) ?? .standard
        }
        return .standard
    }()
}
private final class RecognitionFeed: @unchecked Sendable {
    private let lock=NSLock()
    private var request:SFSpeechAudioBufferRecognitionRequest?
    func set(_ value:SFSpeechAudioBufferRecognitionRequest?){lock.lock();request=value;lock.unlock()}
    func append(_ buffer:AVAudioPCMBuffer){lock.lock();request?.append(buffer);lock.unlock()}
}
@MainActor final class NativeSpeech:ObservableObject {
    @Published var listening=false
    @Published var requesting=false
    @Published var transcript=""
    @Published var level:CGFloat=0
    @Published var levels:[CGFloat]=[]
    @Published var message:String?
    private let audioID=UUID()
    private var recognitionID=UUID()
    private let engine=AVAudioEngine()
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var task:SFSpeechRecognitionTask?
    private var tapInstalled=false
    private var finalText:CheckedContinuation<String,Never>?
    private let feed=RecognitionFeed()
    private var accumulated=DictationTranscript()
    private var rotation:Task<Void,Never>?
    private var finishing=false
    private var sessionID=UUID()
    private var failures=0
    func toggle(){
        #if targetEnvironment(simulator)
        message="Voice input is available on your iPhone. You can type here.";return
        #endif
        if listening || requesting{stop();return};requesting=true;message=nil
        if SFSpeechRecognizer.authorizationStatus() == .authorized{requestMicrophone();return}
        SFSpeechRecognizer.requestAuthorization{status in Task{@MainActor in
            guard self.requesting else{return}
            guard status == .authorized else{self.requesting=false;self.message="Speech permission wasn’t granted. You can still type.";return}
            self.requestMicrophone()
        }}
    }
    private func requestMicrophone(){
        if AVAudioSession.sharedInstance().recordPermission == .granted{start();return}
        AVAudioSession.sharedInstance().requestRecordPermission{granted in Task{@MainActor in
            guard self.requesting else{return}
            guard granted else{self.requesting=false;self.message="Microphone access wasn’t granted. You can still type.";return}
            self.start()
        }}
    }
    private func start(){
        guard let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US")),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{requesting=false;message="On-device transcription isn’t available for this language. Use the keyboard or change your speech language.";return}
        do{
            stop();transcript="";accumulated=DictationTranscript();levels=[];finishing=false;failures=0;sessionID=UUID()
            try NativeAudioSession.activate(audioID,category:.record,mode:.measurement,onReplacement:{[weak self] in self?.stop()})
            listening=true;requesting=false;beginWindow(recognizer)
            let input=engine.inputNode;let format=input.outputFormat(forBus:0);let id=sessionID;let feed=self.feed
            input.installTap(onBus:0,bufferSize:1024,format:format){[weak self] buffer,_ in
                feed.append(buffer)
                if let channel=buffer.floatChannelData?[0]{var rms:Float=0;vDSP_rmsqv(channel,1,&rms,vDSP_Length(buffer.frameLength));let value=AudioMeter.level(rms:rms);Task{@MainActor in guard let self,self.sessionID==id,self.listening else{return};self.level=CGFloat(AudioMeter.smooth(previous:Float(self.level),target:value));self.levels.append(self.level);if self.levels.count>48{self.levels.removeFirst(self.levels.count-48)}}}
            }
            tapInstalled=true;engine.prepare();try engine.start()
        }catch{stop();message="The microphone couldn’t start. Your text is still here."}
    }
    private func beginWindow(_ recognizer:SFSpeechRecognizer){
        rotation?.cancel();request?.endAudio();task?.cancel()
        let id=UUID();recognitionID=id
        let next=SFSpeechAudioBufferRecognitionRequest();next.requiresOnDeviceRecognition=true;next.shouldReportPartialResults=true
        request=next;feed.set(next)
        task=recognizer.recognitionTask(with:next){result,error in Task{@MainActor in
            guard self.recognitionID==id else{return}
            if let result{self.failures=0;self.accumulated.update(result.bestTranscription.formattedString,segmentStart:result.bestTranscription.segments.first?.timestamp);self.transcript=self.accumulated.text}
            if self.finishing{if error != nil || result?.isFinal == true{self.stop()};return}
            if error != nil || result?.isFinal == true{
                guard self.listening else{return}
                self.accumulated.commit()
                if error != nil{self.failures+=1}
                if recognizer.isAvailable,self.failures<3{self.beginWindow(recognizer)}else{self.stop();self.message="Transcription paused because speech recognition became unavailable. Your full text is retained."}
            }
        }}
        rotation=Task{@MainActor in
            try? await Task.sleep(for:.seconds(50));guard !Task.isCancelled,self.recognitionID==id,self.listening,!self.finishing else{return}
            self.accumulated.commit();self.beginWindow(recognizer)
        }
    }
    func finish() async -> String {
        guard listening else{return transcript}
        finishing=true;rotation?.cancel();feed.set(nil)
        engine.stop();if tapInstalled{engine.inputNode.removeTap(onBus:0);tapInstalled=false}
        listening=false;level=0;NativeAudioSession.release(audioID)
        let id=recognitionID
        return await withCheckedContinuation { continuation in
            finalText=continuation;request?.endAudio()
            Task{@MainActor in try? await Task.sleep(for:.milliseconds(1500));guard self.recognitionID==id else{return};self.stop()}
        }
    }
    func stop(){rotation?.cancel();rotation=nil;feed.set(nil);finishing=false;sessionID=UUID();let completion=finalText;finalText=nil;completion?.resume(returning:transcript);recognitionID=UUID();requesting=false;engine.stop();if tapInstalled{engine.inputNode.removeTap(onBus:0);tapInstalled=false};request?.endAudio();task?.cancel();request=nil;task=nil;listening=false;level=0;NativeAudioSession.release(audioID)}
}
struct FilePreview:Identifiable{let id=UUID();let url:URL}
struct NativeFilePreview:UIViewControllerRepresentable {
    var url:URL
    func makeCoordinator()->Coordinator{Coordinator(url:url)}
    func makeUIViewController(context:Context)->QLPreviewController{let controller=QLPreviewController();controller.dataSource=context.coordinator;return controller}
    func updateUIViewController(_ controller:QLPreviewController,context:Context){}
    final class Coordinator:NSObject,QLPreviewControllerDataSource{let url:URL;init(url:URL){self.url=url};func numberOfPreviewItems(in controller:QLPreviewController)->Int{1};func previewController(_ controller:QLPreviewController,previewItemAt index:Int)->QLPreviewItem{url as NSURL}}
}
@MainActor final class PracticePlayer:ObservableObject {
    @Published var duration=0.0
    @Published var seconds=0.0
    @Published var playing=false
    @Published var starting=false
    @Published var speed:Float=1
    @Published var loopStart=0.0
    @Published var loopEnd=0.0
    @Published var looping=false
    @Published var message:String?
    private let audioID=UUID()
    let player:AVPlayer
    private var observer:Any?
    private var statusObserver:NSKeyValueObservation?
    init(url:URL,maximumDuration:Double?=nil){let item=AVPlayerItem(url:url);item.audioTimePitchAlgorithm = .spectral;player=AVPlayer(playerItem:item);observer=player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.1,preferredTimescale:600),queue:.main){[weak self] time in Task{@MainActor in guard let self else{return};self.seconds=time.seconds.isFinite ? time.seconds:0;if self.looping && self.loopEnd>self.loopStart && self.seconds>=self.loopEnd{self.seek(self.loopStart)}else if self.duration>0 && self.seconds>=self.duration{self.player.pause();self.playing=false}}}
        statusObserver=player.observe(\.timeControlStatus,options:[.new]){[weak self] player,_ in let state=player.timeControlStatus;Task{@MainActor in guard let self else{return};self.playing=state == .playing;if state == .playing{self.starting=false};if player.currentItem?.status == .failed{self.starting=false;self.message="This audio file couldn’t be played."}}}
        Task{do{let length=try await item.asset.load(.duration).seconds;duration=length.isFinite ? min(length,maximumDuration ?? length):0;loopEnd=duration}catch{message="This audio file could not be opened."}}
    }
    func toggle(){
        if playing || starting {player.pause();playing=false;starting=false;return}
        do {message=nil;if duration>0 && seconds>=duration{seek(0)};try NativeAudioSession.activate(audioID,category:.playback,mode:.default,onReplacement:{[weak self] in self?.player.pause();self?.playing=false;self?.starting=false});starting=true;player.playImmediately(atRate:speed)}
        catch {starting=false;message="Sound couldn’t start. Check the audio output and try again."}
    }
    func seek(_ seconds:Double){player.seek(to:CMTime(seconds:seconds,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)}
    func stop(){player.pause();playing=false;starting=false;statusObserver=nil;if let observer{player.removeTimeObserver(observer);self.observer=nil}}
}
struct NativeAudioPractice:View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio:PracticePlayer
    init(url:URL){_audio=StateObject(wrappedValue:PracticePlayer(url:url))}
    var body:some View {
        NavigationStack{Form{Section("Playback"){if let message=audio.message{Text(message)};Slider(value:Binding(get:{audio.seconds},set:{audio.seek($0)}),in:0...max(1,audio.duration));HStack{Text(audio.seconds,format:.number.precision(.fractionLength(0)));Spacer();Text(audio.duration,format:.number.precision(.fractionLength(0)))}.font(.caption).foregroundStyle(Design.muted);Button(audio.starting ? "Cancel playback":audio.playing ? "Pause":"Play"){audio.toggle()};Picker("Speed",selection:$audio.speed){Text("0.5×").tag(Float(0.5));Text("0.75×").tag(Float(0.75));Text("1×").tag(Float(1));Text("1.25×").tag(Float(1.25))}.onChange(of:audio.speed){_,speed in if audio.playing{audio.player.rate=speed}};Text("Slower playback preserves pitch.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Section loop"){Toggle("Loop section",isOn:$audio.looping);Button("Set start here · \(Int(audio.loopStart))s"){audio.loopStart=min(audio.seconds,max(0,audio.loopEnd-0.2))};Button("Set end here · \(Int(audio.loopEnd))s"){audio.loopEnd=max(audio.seconds,audio.loopStart+0.2)}}
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Practice").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){audio.stop();dismiss()}}}}.onDisappear{audio.stop()}
    }
}
@MainActor final class NativeMetronome:ObservableObject {
    private let audioID=UUID()
    @Published var bpm=100
    @Published var playing=false
    @Published var startedAt=Date()
    @Published var message:String?
    private let engine=AVAudioEngine()
    private let player=AVAudioPlayerNode()
    private let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    init(){engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:format)}
    func toggle(){if playing{stop();return};message=nil
        do {try NativeAudioSession.activate(audioID,category:.playback,mode:.default,onReplacement:{[weak self] in self?.stop()});let samples=BeatAudio.samples(bpm:bpm);guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)),let channel=buffer.floatChannelData?[0] else{throw CoreError.database("audio buffer unavailable")};buffer.frameLength=AVAudioFrameCount(samples.count);for index in samples.indices{channel[index]=samples[index]};player.scheduleBuffer(buffer,at:nil,options:.loops);try engine.start();player.play();startedAt=Date();playing=engine.isRunning && player.isPlaying;if !playing{throw CoreError.database("audio output unavailable")}}
        catch {stop();message="Sound couldn’t start. Check the audio output and try again."}
    }
    func changeBPM(){if playing{stop();toggle()}}
    func stop(){player.stop();engine.stop();playing=false;NativeAudioSession.release(audioID)}
}
struct NativeRehearsal:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    let songs:[EdizCore.Record]
    @State private var index=0
    @StateObject private var metronome=NativeMetronome()
    @State private var tempoText="100"
    @State private var taps:[Date]=[]
    @FocusState private var editingTempo:Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func applyTempo(){if let value=Int(tempoText){metronome.bpm=min(240,max(30,value))};tempoText=String(metronome.bpm)}
    func adjustTempo(_ amount:Int){store.walkthrough?.event("rehearsal-tempo");applyTempo();editingTempo=false;metronome.bpm=min(240,max(30,metronome.bpm+amount));tempoText=String(metronome.bpm)}
    func tapTempo(){store.walkthrough?.event("rehearsal-tempo");let now=Date();if let last=taps.last,now.timeIntervalSince(last)>3{taps=[]};taps.append(now);taps=Array(taps.suffix(6));guard taps.count>1 else{return};let interval=now.timeIntervalSince(taps[0])/Double(taps.count-1);guard interval>0 else{return};editingTempo=false;metronome.bpm=min(240,max(30,Int((60/interval).rounded())));tempoText=String(metronome.bpm)}
    func applySongTempo(){if songs.indices.contains(index),let bpm=Int(songs[index].data["BPM"] ?? ""),(30...240).contains(bpm){metronome.bpm=bpm}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack { VStack(alignment:.leading,spacing:4){Text("CLEARANCE 19").font(Design.font(13));Text("Rehearsal").font(Design.font(22))};Spacer();Button("Close"){metronome.stop();dismiss()}.buttonStyle(ActionStyle()) }
                if songs.indices.contains(index) {
                    let song=songs[index]
                    VStack(alignment:.leading,spacing:12) {
                        Text("Song \(index+1) of \(songs.count)").font(.subheadline).foregroundStyle(Design.muted)
                        Text(song.title).font(Design.font(34)).fixedSize(horizontal:false,vertical:true)
                        if let artist=song.data["artist"],!artist.isEmpty {Text(artist).font(Design.font(17,weight:"Regular")).foregroundStyle(Design.muted)}
                        if let tuning=song.data["tuning"],!tuning.isEmpty {Label(tuning,systemImage:"guitars").font(.subheadline).foregroundStyle(Design.muted)}
                    }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:26))
                    let notes=song.data["structure"].flatMap{$0.isEmpty ? nil:$0} ?? song.body
                    if !notes.isEmpty { VStack(alignment:.leading,spacing:12){Text("For this song").font(Design.font(16));Text(notes).font(Design.font(19,weight:"Regular")).textSelection(.enabled)}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:24)) }
                    VStack(alignment:.leading,spacing:12) {
                        Text("Setlist").font(Design.font(17))
                        ForEach(Array(songs.enumerated()),id:\.element.id){position,item in
                            Button {index=position} label:{HStack(spacing:14){Text(String(position+1)).font(.subheadline.monospacedDigit()).foregroundStyle(Design.muted).frame(width:24);Text(item.title).font(Design.font(17,weight:"Regular")).frame(maxWidth:.infinity,alignment:.leading);if position == index{Image(systemName:"waveform").foregroundStyle(Design.color(0xbd7a7d))}}.padding(14).frame(minHeight:50).background(position == index ? Design.raised:Design.surface,in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain).accessibilityLabel("Select \(item.title)").accessibilityAddTraits(position == index ? .isSelected:[])
                        }
                    }
                } else { QuietEmpty(title:"Your setlist starts here.",message:"Add songs in CLEARANCE 19. The metronome is ready to use meanwhile.") }
            }.padding(20)
        }
        .safeAreaInset(edge:.bottom,spacing:0) {
            VStack(spacing:16) {
                TimelineView(.periodic(from:metronome.startedAt,by:60/Double(metronome.bpm))){context in
                    let beat=Int(max(0,context.date.timeIntervalSince(metronome.startedAt))*Double(metronome.bpm)/60)%4
                    HStack(spacing:12){ForEach(0..<4,id:\.self){number in Capsule().fill(metronome.playing && beat == number ? Design.ink:Design.raised).frame(width:number == 0 ? 26:12,height:12)}}.frame(maxWidth:.infinity).animation(reducedMotion ? nil:.easeOut(duration:0.12),value:beat).accessibilityLabel(metronome.playing ? "Beat \(beat+1) of 4":"Metronome stopped")
                }
                HStack(spacing:10){
                    Button{adjustTempo(-1)}label:{Image(systemName:"minus").frame(width:44,height:44).background(Design.raised,in:Circle())}.buttonStyle(.plain).disabled(metronome.bpm<=30).accessibilityLabel("Decrease tempo")
                    TextField("BPM",text:$tempoText).keyboardType(.numberPad).focused($editingTempo).font(.title.monospacedDigit().weight(.medium)).multilineTextAlignment(.center).frame(width:80).padding(.vertical,8).background(Design.raised,in:RoundedRectangle(cornerRadius:12)).accessibilityLabel("Metronome BPM").accessibilityIdentifier("metronome-bpm").walkthroughTarget("tempo",session:store.walkthrough)
                    Text("BPM").font(.caption).foregroundStyle(Design.muted)
                    Button{adjustTempo(1)}label:{Image(systemName:"plus").frame(width:44,height:44).background(Design.raised,in:Circle())}.buttonStyle(.plain).disabled(metronome.bpm>=240).accessibilityLabel("Increase tempo")
                    }
                HStack { Text("30–240 BPM · Tap the number to type").font(.caption).foregroundStyle(Design.muted);Spacer(minLength:8)
                    if editingTempo{Button{applyTempo();editingTempo=false}label:{Image(systemName:"checkmark").frame(width:44,height:44).background(Design.raised,in:Circle())}.buttonStyle(.plain).accessibilityLabel("Apply tempo")}
                    else{Button{tapTempo()}label:{Text("Tap").font(.subheadline.weight(.medium)).frame(width:54,height:44).background(Design.raised,in:Capsule())}.buttonStyle(.plain).accessibilityLabel("Tap tempo")}
                }
                HStack(spacing:12) {
                    if !songs.isEmpty {Button {index=max(0,index-1)} label:{Image(systemName:"backward.end.fill").frame(width:20)}.buttonStyle(ActionStyle()).disabled(index == 0).accessibilityLabel("Previous")}
                    Button(metronome.playing ? "Stop metronome":"Start metronome"){store.walkthrough?.muteForRecording();metronome.toggle();if metronome.playing{store.walkthrough?.event("rehearsal-start",narrate:false)}else{store.walkthrough?.event("rehearsal-stop")}}.buttonStyle(ActionStyle()).walkthroughTarget("metronome",session:store.walkthrough).frame(maxWidth:.infinity)
                    if !songs.isEmpty {Button {index=min(songs.count-1,index+1)} label:{Image(systemName:"forward.end.fill").frame(width:20)}.buttonStyle(ActionStyle()).disabled(index>=songs.count-1).accessibilityLabel("Next")}
                }
                if let message=metronome.message {Text(message).font(.footnote).foregroundStyle(Design.muted)}
            }.padding(.horizontal,20).padding(.vertical,14).background(Design.background).overlay(alignment:.top){Rectangle().fill(Design.muted.opacity(0.18)).frame(height:1)}
        }
        .background(AppBackdrop(scope:"band")).foregroundStyle(Design.ink).preferredColorScheme(.dark)
        .simultaneousGesture(DragGesture(minimumDistance:50).onEnded{value in guard abs(value.translation.width)>abs(value.translation.height)*1.5 else{return};index=value.translation.width<0 ? min(max(0,songs.count-1),index+1):max(0,index-1)})
        .safeAreaInset(edge:.top){if let session=store.walkthrough{WalkthroughCoach(session:session)}}
        .onAppear{if store.isPractice{store.practiceOverlay=true};applySongTempo();tempoText=String(metronome.bpm);store.walkthrough?.event("rehearsal-open")}.onChange(of:index){_,_ in editingTempo=false;applySongTempo();tempoText=String(metronome.bpm)}.onChange(of:editingTempo){_,editing in if editing{DispatchQueue.main.asyncAfter(deadline:.now()+0.1){if editingTempo{UIApplication.shared.sendAction(NSSelectorFromString("selectAll:"),to:nil,from:nil,for:nil)}}}else{applyTempo()}}.onChange(of:metronome.bpm){_,_ in if !editingTempo{tempoText=String(metronome.bpm)};metronome.changeBPM();store.walkthrough?.event("rehearsal-tempo")}
        .animation(reducedMotion ? nil:.easeInOut(duration:0.18),value:index).onDisappear{metronome.stop();store.practiceOverlay=false}
    }
}

struct AssistantAttachment:Identifiable {
    let id=UUID()
    let name:String
    let mimeType:String
    let bytes:Data
    var symbol:String{mimeType.hasPrefix("image/") ? "photo":mimeType.hasPrefix("video/") ? "video":mimeType.hasPrefix("audio/") ? "waveform":"doc.text"}
}
struct AssistantAttachmentInfo:Codable,Identifiable {
    var id=UUID()
    let name:String
    let mimeType:String
    var localFile:String?
}
enum AssistantMedia {
    static let limit=2_500_000
    static func prepare(_ url:URL) async throws -> AssistantAttachment {
        let type=UTType(filenameExtension:url.pathExtension) ?? .data
        let name=UUID(uuidString:url.deletingPathExtension().lastPathComponent) != nil ? (type.conforms(to:.movie) ? "Video.mp4":"Photo.jpg"):String(url.lastPathComponent.prefix(180))
        if type.conforms(to:.movie) {
            let asset=AVURLAsset(url:url)
            let duration=try await asset.load(.duration)
            guard duration.seconds <= 60 else{throw issue("Choose a video of 60 seconds or less for this connection.")}
            guard let export=AVAssetExportSession(asset:asset,presetName:AVAssetExportPreset640x480) else{throw issue("This video format couldn’t be prepared.")}
            let output=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mp4")
            defer{try? FileManager.default.removeItem(at:output)}
            try await export.export(to:output,as:.mp4)
            guard (try output.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? limit+1)<=limit else{throw issue("This video is still too large. Choose a shorter clip; attachments can total 2.5 MB.")}
            return .init(name:name,mimeType:"video/mp4",bytes:try Data(contentsOf:output))
        }
        guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? limit+1) <= (type.conforms(to:.image) ? 50_000_000:limit) else{throw issue("Choose a smaller file; attachments can total 2.5 MB.")}
        let data=try Data(contentsOf:url)
        if type.conforms(to:.image) {
            guard let source=CGImageSourceCreateWithData(data as CFData,nil),let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1600,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),let bytes=UIImage(cgImage:image).jpegData(compressionQuality:0.78) else{throw issue("This photo couldn’t be read.")}
            return .init(name:name,mimeType:"image/jpeg",bytes:bytes)
        }
        let audioTypes=["wav":"audio/wav","mp3":"audio/mpeg","m4a":"audio/mp4","aac":"audio/aac","aiff":"audio/aiff","aif":"audio/aiff","flac":"audio/flac","ogg":"audio/ogg"]
        if let mime=audioTypes[url.pathExtension.lowercased()]{return .init(name:String(url.lastPathComponent.prefix(180)),mimeType:mime,bytes:data)}
        if type.conforms(to:.pdf){return .init(name:name,mimeType:"application/pdf",bytes:data)}
        if type.conforms(to:.text)||["txt","md","csv","json"].contains(url.pathExtension.lowercased()),String(data:data,encoding:.utf8) != nil {return .init(name:name,mimeType:"text/plain",bytes:data)}
        throw issue("Use a photo, short video, audio recording, PDF, or a text, Markdown, CSV or JSON file.")
    }
    static func issue(_ text:String)->NSError{NSError(domain:"AssistantMedia",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
}
struct NativeAssistantMediaPicker:UIViewControllerRepresentable {
    var receive:(URL)->Void
    var close:()->Void
    var failed:(String)->Void
    func makeUIViewController(context:Context)->PHPickerViewController {
        var config=PHPickerConfiguration();config.filter = .any(of:[.images,.videos]);config.selectionLimit=3
        let picker=PHPickerViewController(configuration:config);picker.delegate=context.coordinator;return picker
    }
    func updateUIViewController(_ controller:PHPickerViewController,context:Context){}
    func makeCoordinator()->Coordinator{Coordinator(receive:receive,close:close,failed:failed)}
    final class Coordinator:NSObject,PHPickerViewControllerDelegate {
        let receive:(URL)->Void
        let close:()->Void
        let failed:(String)->Void
        init(receive:@escaping(URL)->Void,close:@escaping()->Void,failed:@escaping(String)->Void){self.receive=receive;self.close=close;self.failed=failed}
        func picker(_ picker:PHPickerViewController,didFinishPicking results:[PHPickerResult]) {
            close()
            for result in results {
                let provider=result.itemProvider
                let type=provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ? UTType.movie.identifier:UTType.image.identifier
                provider.loadFileRepresentation(forTypeIdentifier:type){url,error in
                    guard let url else{DispatchQueue.main.async{self.failed("That photo or video couldn’t be loaded. Try again when it’s available on this phone.")};return}
                    let copy=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+"."+url.pathExtension)
                    do{try FileManager.default.copyItem(at:url,to:copy);DispatchQueue.main.async{self.receive(copy)}}catch{DispatchQueue.main.async{self.failed("That media couldn’t be prepared. Try choosing it again.")}}
                }
            }
        }
    }
}
@MainActor final class NativeAssistantSpeaker:NSObject,ObservableObject,AVAudioPlayerDelegate {
    @Published var speaking=false
    @Published var preparing=false
    @Published var paused=false
    @Published var voiceNote:String?
    @Published var level:CGFloat=0
    @Published var output="iPhone"
    @Published var muted=false
    private let audioID=UUID()
    private let engine=AVAudioEngine()
    private let node=AVAudioPlayerNode()
    private let timePitch=AVAudioUnitTimePitch()
    private var playbackRate:Float=1
    private let synthesizer=AVSpeechSynthesizer()
    private var utterance:AVSpeechUtterance?
    private var meter:Task<Void,Never>?
    private var generation:Task<Void,Never>?
    private var playbackID=UUID()
    private var tapInstalled=false
    private var pending=0
    private var queuedSeconds:Double=0
    private var ended=false
    private var cache:[String:Data]=[:]
    var allowOfflineVoice:Bool{NativeVoicePreferences.defaults.bool(forKey:"assistant-offline-voice")}
    private let format=AVAudioFormat(standardFormatWithSampleRate:24000,channels:1)!
    var finished:(()->Void)?
    var failed:((String)->Void)?
    var interrupted:((String)->Void)?
    private var interruptionRequest:SFSpeechAudioBufferRecognitionRequest?
    private var interruptionTask:SFSpeechRecognitionTask?
    private var inputTapInstalled=false
    private var voiceProcessing=false
    private var recordedPlayer:AVAudioPlayer?
    private var recordedQueue:[URL]=[]
    private var recordedMeter:Task<Void,Never>?
    override init(){super.init();engine.attach(node);engine.attach(timePitch)}
    func setPlaybackRate(_ rate:Float){playbackRate=min(1.5,max(0.75,rate));timePitch.rate=playbackRate;recordedPlayer?.rate=playbackRate}
    func pausePlayback(){paused=true;node.pause();recordedPlayer?.pause();speaking=false;level=0}
    func resumePlayback(){guard paused else{return};paused=false;if engine.isRunning && pending>0{node.play();speaking=true};if let recordedPlayer,recordedPlayer.play(){speaking=true}}
    func say(_ text:String,token:String?=nil,natural:Bool=true,voice:String="Aoede",recordingURL:URL?=nil,playback:Bool=true,preferredSpeechModel:String?="live") {
        stop();voiceNote=nil
        let text=text.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else{return}
        guard natural,let token else{if !natural || allowOfflineVoice{deviceSay(text)}else{voiceNote="Connect your assistant to hear your chosen natural voice."};return}
        let key=voice+":"+text
        if recordingURL == nil,let audio=cache[key]{do{try queuePCM(audio);voiceNote="Natural voice · "+voice;ended=true;completeIfDrained()}catch{voiceNote="Audio couldn’t start. Check the output and try again."};return}
        preparing=true;let id=playbackID
        generation=Task{@MainActor in
            var cacheAudio=Data();var cacheable=true;var heardAudio=false;var streamIssue:String?;var speechModel=preferredSpeechModel
            let temporaryURL=recordingURL?.deletingPathExtension().appendingPathExtension("partial.m4a")
            var recordingFile:AVAudioFile?
            do {
                if let temporaryURL {
                    try FileManager.default.createDirectory(at:temporaryURL.deletingLastPathComponent(),withIntermediateDirectories:true)
                    try? FileManager.default.removeItem(at:temporaryURL)
                    recordingFile=try AVAudioFile(forWriting:temporaryURL,settings:[AVFormatIDKey:Int(kAudioFormatMPEG4AAC),AVSampleRateKey:24000,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:48000],commonFormat:.pcmFormatFloat32,interleaved:false)
                }
                for chunk in SpeechText.chunks(text,limit:speechModel == "live" ? 260:700){
                    // Let the current audio play before requesting the next segment.
                    // Immediate requests can exhaust one model's short rate window and change the voice.
                    while speechModel != nil && (paused || queuedSeconds>10){try Task.checkCancellation();try await Task.sleep(for:.milliseconds(250))}
                    while paused{try Task.checkCancellation();try await Task.sleep(for:.milliseconds(150))}
                    try Task.checkCancellation();guard playbackID==id else{return}
                    var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!)
                    request.httpMethod="POST";request.timeoutInterval=110
                    request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
                    var payload:[String:Any]=["mode":"speech-stream","text":chunk,"voice":voice]
                    if let speechModel{payload["speechModel"]=speechModel}
                    request.httpBody=try JSONSerialization.data(withJSONObject:payload)
                    let (bytes,response)=try await URLSession.shared.bytes(for:request)
                    guard (response as? HTTPURLResponse)?.statusCode==200 else{throw URLError(.badServerResponse)}
                    var completed=false;var chunkBytes=0
                    for try await line in bytes.lines {
                        try Task.checkCancellation();guard playbackID==id else{return}
                        guard !line.isEmpty,let data=line.data(using:.utf8),let packet=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{continue}
                        if let issue=packet["error"] as? String{streamIssue=issue;throw URLError(.cannotLoadFromNetwork)}
                        if let encoded=packet["audio"] as? String,let audio=Data(base64Encoded:encoded){
                            if let model=packet["model"] as? String{if let speechModel,speechModel != model{throw URLError(.cannotDecodeContentData)};speechModel=model}
                            while paused{try Task.checkCancellation();try await Task.sleep(for:.milliseconds(150))}
                            guard packet["rate"] as? Int==24000,chunkBytes+audio.count<=4000000 else{throw URLError(.cannotDecodeContentData)}
                            chunkBytes+=audio.count;heardAudio=true
                            if cacheable,cacheAudio.count+audio.count<=1500000{cacheAudio.append(audio)}else{cacheable=false;cacheAudio.removeAll()}
                            let buffer=try pcmBuffer(audio)
                            try recordingFile?.write(from:buffer)
                            if playback{try queue(buffer)}
                            voiceNote="Natural voice · "+voice
                        }
                        if packet["done"] as? Bool==true{completed=true}
                    }
                    guard completed,chunkBytes>0 else{throw URLError(.networkConnectionLost)}
                }
                recordingFile=nil
                if let temporaryURL,let recordingURL{try? FileManager.default.removeItem(at:recordingURL);try FileManager.default.moveItem(at:temporaryURL,to:recordingURL);try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:recordingURL.path)}
                if cacheable,!cacheAudio.isEmpty{if cache.count>=3{cache.removeAll()};cache[key]=cacheAudio}
                if !playback{preparing=false;let completion=finished;Task{@MainActor in await Task.yield();completion?()};return}
                ended=true;completeIfDrained()
            }catch {
                guard !Task.isCancelled,playbackID==id else{return}
                recordingFile=nil;if let temporaryURL{try? FileManager.default.removeItem(at:temporaryURL)}
                if !heardAudio{resetPlayback();preparing=false;if allowOfflineVoice && recordingURL == nil{deviceSay(text)}else{voiceNote=streamIssue ?? "Your natural voice couldn’t play. Tap Read aloud to retry; your reply is still here.";failed?(voiceNote ?? "Speech unavailable")}}
                else{voiceNote="Speech stopped before this chapter finished. Retry from the start of this chapter.";finished=nil;failed?(voiceNote ?? "Speech interrupted");ended=true;completeIfDrained()}
            }
        }
    }
    func acknowledgeInterruption(_ completion:@escaping ()->Void){
        stop()
        let previousInterruption=interrupted;let previousFinished=finished
        interrupted=nil
        finished={ [weak self] in guard let self else{return};self.interrupted=previousInterruption;self.finished=previousFinished;completion() }
        let voice=NativeVoicePreferences.defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede"
        let preferred=Bundle.main.url(forResource:"go-ahead",withExtension:"m4a",subdirectory:"GuideAudio/"+voice)
        if let clip=preferred ?? Bundle.main.url(forResource:"go-ahead",withExtension:"m4a",subdirectory:"GuideAudio/Aoede"){
            playRecorded([clip],voice:preferred == nil ? "Aoede":voice)
        }else{voiceNote="Go ahead — I’m listening.";finished=nil;interrupted=previousInterruption;self.finished=previousFinished;completion()}
    }
    func playRecorded(_ urls:[URL],voice:String){
        stop();voiceNote=nil;guard !urls.isEmpty else{voiceNote="This guide recording couldn’t be found. Try reopening the guide.";return}
        recordedQueue=urls
        do{try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio,onReplacement:{[weak self] in self?.stop()});try nextRecording();voiceNote="Recorded natural voice · "+voice}
        catch{stop();voiceNote="The guide recording couldn’t play: "+error.localizedDescription}
    }
    private func nextRecording() throws {
        guard !recordedQueue.isEmpty else{recordedMeter?.cancel();recordedMeter=nil;recordedPlayer=nil;speaking=false;level=0;NativeAudioSession.release(audioID);finished?();return}
        let next=try AVAudioPlayer(contentsOf:recordedQueue.removeFirst());next.delegate=self;next.isMeteringEnabled=true;next.enableRate=true;next.rate=playbackRate;next.volume=1;next.prepareToPlay();recordedPlayer=next
        guard next.play() else{throw URLError(.cannotDecodeContentData)}
        speaking=true;preparing=false;recordedMeter?.cancel()
        recordedMeter=Task{@MainActor in while !Task.isCancelled,self.recordedPlayer===next{next.updateMeters();self.level=CGFloat(AudioMeter.level(decibels:next.averagePower(forChannel:0)));self.refreshOutput();try? await Task.sleep(for:.milliseconds(50))}}
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool){Task{@MainActor in guard self.recordedPlayer===player else{return};do{guard flag else{throw URLError(.cannotDecodeContentData)};try self.nextRecording()}catch{self.stop();self.voiceNote="The guide was interrupted. Replay this step."}}}
    private func queuePCM(_ bytes:Data) throws {
        try queue(pcmBuffer(bytes))
    }
    private func pcmBuffer(_ bytes:Data) throws -> AVAudioPCMBuffer {
        guard !bytes.isEmpty,bytes.count%2==0,let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(bytes.count/2)),let samples=buffer.floatChannelData?[0] else{throw URLError(.cannotDecodeContentData)}
        buffer.frameLength=buffer.frameCapacity
        bytes.withUnsafeBytes{raw in for index in 0..<Int(buffer.frameLength){samples[index]=Float(Int16(littleEndian:raw.loadUnaligned(fromByteOffset:index*2,as:Int16.self)))/32768}}
        return buffer
    }
    private func queue(_ buffer:AVAudioPCMBuffer) throws {
        let id=playbackID
        if !engine.isRunning {
            if tapInstalled{engine.mainMixerNode.removeTap(onBus:0);tapInstalled=false}
            if inputTapInstalled{engine.inputNode.removeTap(onBus:0);inputTapInstalled=false}
            interruptionTask?.cancel();interruptionTask=nil;interruptionRequest?.endAudio();interruptionRequest=nil
            if interrupted != nil,AVAudioSession.sharedInstance().recordPermission == .granted,SFSpeechRecognizer.authorizationStatus() == .authorized {
                try NativeAudioSession.activate(audioID,category:.playAndRecord,mode:.voiceChat,onReplacement:{[weak self] in self?.stop()})
                try engine.inputNode.setVoiceProcessingEnabled(true);voiceProcessing=true
                beginInterruptionRecognition(id:id)
            }else{try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio,onReplacement:{[weak self] in self?.stop()})}
            engine.connect(node,to:timePitch,format:buffer.format);engine.connect(timePitch,to:engine.mainMixerNode,format:buffer.format);timePitch.rate=playbackRate
            engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil){[weak self] buffer,_ in
                guard let samples=buffer.floatChannelData?[0] else{return};var rms:Float=0;vDSP_rmsqv(samples,1,&rms,vDSP_Length(buffer.frameLength));let value=AudioMeter.level(rms:rms)
                Task{@MainActor in guard let self,self.playbackID==id else{return};self.level=CGFloat(AudioMeter.smooth(previous:Float(self.level),target:value))}
            };tapInstalled=true;engine.prepare();try engine.start();monitorOutput()
        }
        pending+=1
        let duration=Double(buffer.frameLength)/buffer.format.sampleRate
        queuedSeconds+=duration
        node.scheduleBuffer(buffer,completionCallbackType:.dataPlayedBack){[weak self] _ in Task{@MainActor in guard let self,self.playbackID==id else{return};self.pending=max(0,self.pending-1);self.queuedSeconds=max(0,self.queuedSeconds-duration);self.completeIfDrained()}}
        if !node.isPlaying && !paused{node.play()}
        preparing=false;speaking = !paused
    }
    private func deviceSay(_ text:String) {
        preparing=true;let id=playbackID
        let utterance=AVSpeechUtterance(string:text);let recognizer=NLLanguageRecognizer();recognizer.processString(text)
        let language=recognizer.dominantLanguage?.rawValue ?? Locale.current.language.languageCode?.identifier ?? "en"
        let voices=AVSpeechSynthesisVoice.speechVoices().filter{$0.language.hasPrefix(language) && !$0.identifier.lowercased().contains("novelty")}
        let preferred=["Ava","Serena","Evan","Tom","Fiona","Alex","Zoe","Anna"]
        func score(_ voice:AVSpeechSynthesisVoice)->Int{voice.quality.rawValue*100+(preferred.firstIndex(of:voice.name).map{30-$0} ?? 0)}
        utterance.voice=voices.max{score($0)<score($1)} ?? AVSpeechSynthesisVoice(language:language)
        voiceNote="Offline backup · "+(utterance.voice?.name ?? "System")+(utterance.voice?.quality == .default ? "":" · Enhanced")
        utterance.rate=AVSpeechUtteranceDefaultSpeechRate * 0.94;utterance.pitchMultiplier=1;self.utterance=utterance
        if voiceNote==nil{voiceNote="Device voice"}
        synthesizer.write(utterance){[weak self] audio in
            guard let buffer=audio as? AVAudioPCMBuffer else{return}
            Task{@MainActor in
                guard let self,self.playbackID==id else{return}
                if buffer.frameLength==0{self.ended=true;self.completeIfDrained();return}
                do{try self.queue(buffer)}catch{self.stop();self.voiceNote="Audio couldn’t start. Check the output and try again."}
            }
        }
    }
    private func beginInterruptionRecognition(id:UUID){
        guard !inputTapInstalled else{return}
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US")),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{return}
        let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;interruptionRequest=request
        let input=engine.inputNode
        input.installTap(onBus:0,bufferSize:1024,format:input.outputFormat(forBus:0)){buffer,_ in request.append(buffer)};inputTapInstalled=true
        interruptionTask=recognizer.recognitionTask(with:request){[weak self] result,_ in
            guard let result else{return};let text=result.bestTranscription.formattedString.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !text.isEmpty else{return}
            Task{@MainActor in guard let self,self.playbackID==id,self.speaking,let interrupted=self.interrupted else{return};self.stop();interrupted(text)}
        }
    }
    private func completeIfDrained(){guard ended,pending==0 else{return};resetPlayback();finished?()}
    func refreshOutput(){let session=AVAudioSession.sharedInstance();output=session.currentRoute.outputs.map(\.portName).joined(separator:", ");muted=session.outputVolume<0.01}
    private func monitorOutput(){meter?.cancel();meter=Task{@MainActor in while !Task.isCancelled{refreshOutput();try? await Task.sleep(for:.milliseconds(100))}}}
    private func resetPlayback(){playbackID=UUID();interruptionTask?.cancel();interruptionTask=nil;interruptionRequest?.endAudio();interruptionRequest=nil;if inputTapInstalled{engine.inputNode.removeTap(onBus:0);inputTapInstalled=false};meter?.cancel();meter=nil;node.stop();if tapInstalled{engine.mainMixerNode.removeTap(onBus:0);tapInstalled=false};engine.stop();if voiceProcessing{try? engine.inputNode.setVoiceProcessingEnabled(false);voiceProcessing=false};pending=0;queuedSeconds=0;ended=false;preparing=false;speaking=false;paused=false;level=0;NativeAudioSession.release(audioID)}
    func stop(){recordedMeter?.cancel();recordedMeter=nil;recordedPlayer?.stop();recordedPlayer=nil;recordedQueue=[];generation?.cancel();generation=nil;resetPlayback();utterance=nil;synthesizer.stopSpeaking(at:.immediate)}
}
private struct CallScrollOffset:PreferenceKey {static let defaultValue:CGFloat=0;static func reduce(value:inout CGFloat,nextValue:()->CGFloat){value=nextValue()}}
struct NativeAssistantVoicePanel:View {
    @EnvironmentObject var store:NativeStore
    @AppStorage("assistant-natural-voice",store:NativeVoicePreferences.defaults) private var naturalVoice=true
    @AppStorage("assistant-natural-voice-name",store:NativeVoicePreferences.defaults) private var voiceName="Aoede"
    @State private var settings=false
    @State private var captions=false
    @State private var resultScroll:CGFloat=0
    @State private var showingResults=true
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @ObservedObject var speech:NativeSpeech
    @ObservedObject var speaker:NativeAssistantSpeaker
    let busy:Bool
    let entry:ConversationEntry?
    var reply:String{entry?.text ?? ""}
    var linkedRecords:[EdizCore.Record]{(entry?.records ?? []).compactMap{linked in store.records.first{$0.id == linked.id}}}
    var hasResults:Bool{entry?.presentResults == true && (entry?.musicPreview != nil || !(entry?.cards ?? []).isEmpty || !(entry?.actions ?? []).isEmpty || !linkedRecords.isEmpty || !(entry?.sources ?? []).isEmpty)}
    @State private var proposal:GeminiProposal?
    @State private var recordPreview:EdizCore.Record?
    @State private var began=false
    let error:String?
    let scope:String
    let listen:()->Void
    let pause:()->Void
    let send:()->Void
    let read:()->Void
    let end:()->Void
    var accent:Color{WorkspaceTheme.accent(scope)}
    var status:String{speaker.preparing ? "Preparing your voice…":busy ? "Thinking…":speaker.speaking ? "Your assistant is speaking":speech.listening ? "Listening to you":"Ready when you are"}
    var level:CGFloat{speaker.speaking ? speaker.level:speech.level}
    var active:Bool{speech.listening || speaker.speaking || busy || speaker.preparing}
    var activityColor:Color{busy || speaker.preparing ? Design.ink:active ? accent:Design.muted}
    var body:some View {
        GeometryReader { geometry in
            VStack(spacing:0){
                HStack(spacing:12){
                    Button(action:end){Image(systemName:"xmark").font(.body.weight(.medium)).frame(width:44,height:44).contentShape(Rectangle())}.accessibilityLabel("End conversation").accessibilityIdentifier("voice-done")
                    Spacer(minLength:0)
                    VStack(spacing:4){Text(WorkspaceBot.name(scope)).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8);Text("Voice conversation").font(.caption).foregroundStyle(Design.muted)}
                    Spacer(minLength:0)
                    Button{pause();settings=true}label:{Image(systemName:"slider.horizontal.3").font(.body).frame(width:44,height:44).contentShape(Rectangle())}.accessibilityLabel("Voice settings").accessibilityIdentifier("voice-settings")
                }.padding(.horizontal,16).padding(.top,4).padding(.bottom,12)
                if hasResults,showingResults,let entry{
                    HStack(spacing:16){
                        VStack(alignment:.leading,spacing:6){Button{withAnimation(reducedMotion ? nil:.easeOut(duration:0.2)){showingResults=false}}label:{Label("Back to voice",systemImage:"waveform")}.font(.caption);Text(status).font(.subheadline.weight(.medium));Text(speech.listening && !speech.transcript.isEmpty ? speech.transcript:"Your results stay here while we talk.").font(.caption).foregroundStyle(Design.muted).lineLimit(2)}
                        Spacer(minLength:0)
                        activity.frame(width:64,height:64).opacity(max(0.4,1-Double(resultScroll)/240))
                    }.padding(.horizontal,24).padding(.bottom,8)
                    ScrollView{
                        VStack(alignment:.leading,spacing:16){
                            GeometryReader{proxy in Color.clear.preference(key:CallScrollOffset.self,value:proxy.frame(in:.named("call-results")).minY)}.frame(height:0)
                            if let preview=entry.musicPreview{NativeSongPreview(preview:preview,beforePlayback:pause,autoPlay:true,playbackKey:entry.id)}
                            ForEach(entry.cards ?? []){AssistantResultCard(card:$0,scope:scope,onOpen:pause)}
                            if !linkedRecords.isEmpty{VStack(alignment:.leading,spacing:12){Text("Saved items").font(.caption.weight(.medium)).foregroundStyle(Design.muted);ForEach(linkedRecords){record in Button{pause();recordPreview=record}label:{HStack{VStack(alignment:.leading,spacing:5){Text(record.title).font(.headline);Text(Catalog.space(record.space).name).font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.up.right.square")}.padding(16).foregroundStyle(Design.ink).background(Design.surface,in:RoundedRectangle(cornerRadius:16))}.accessibilityIdentifier("voice-record-"+record.id)}}}
                            if !entry.actions.isEmpty{Text("Changes to review · nothing saved yet").font(.caption).foregroundStyle(Design.muted)}
                            ForEach(entry.actions){action in Button("Review: "+action.title){pause();proposal=action}.buttonStyle(ActionStyle()).accessibilityIdentifier("voice-review-"+action.id)}
                            if captions || (entry.cards ?? []).isEmpty,!reply.isEmpty{Text(reply).font(.subheadline).lineSpacing(4).foregroundStyle(Design.ink).textSelection(.enabled)}
                            if !entry.sources.isEmpty{Text("Web sources").font(.caption.weight(.medium)).foregroundStyle(Design.muted);ForEach(entry.sources,id:\.url){source in if let url=URL(string:source.url),url.scheme == "https"{Link(source.title,destination:url).font(.subheadline)}}}
                            if let html=entry.searchSuggestions,!html.isEmpty{NativeSearchSuggestions(html:html).frame(height:110)}
                        }.padding(.horizontal,20).padding(.vertical,8)
                    }.safeAreaPadding(.vertical,18).coordinateSpace(name:"call-results").onPreferenceChange(CallScrollOffset.self){resultScroll=max(0,-$0)}.frame(maxWidth:.infinity,maxHeight:.infinity).accessibilityIdentifier("voice-results")
                }else{
                    Spacer(minLength:8)
                    if hasResults{Button{withAnimation(reducedMotion ? nil:.easeOut(duration:0.2)){showingResults=true}}label:{Label("View shared result",systemImage:"rectangle.on.rectangle")}.font(.subheadline)}
                    activity.frame(maxWidth:.infinity).frame(height:max(180,min(geometry.size.height*0.4,330)))
                    Text(status).font(.title3.weight(.medium)).padding(.top,10)
                    Text(speech.listening ? "I’m listening. Pause when you’re ready.":"A little room to think out loud.").font(.subheadline).foregroundStyle(Design.muted).padding(.top,8)
                    Text(captions ? (speech.listening ? speech.transcript:reply):"").font(.subheadline).lineSpacing(4).lineLimit(4).frame(maxWidth:.infinity,minHeight:76,alignment:.center).padding(.horizontal,28).padding(.top,16)
                    Spacer(minLength:8)
                }
                if let message=error ?? speech.message{Text(message).font(.footnote).foregroundStyle(Design.muted).padding(.horizontal,24).padding(.top,8)}
                if let note=speaker.voiceNote{Text(note).font(.caption).foregroundStyle(Design.muted).padding(.top,6)}
                HStack(spacing:28){
                    Button{withAnimation(reducedMotion ? nil:.easeInOut(duration:0.2)){captions.toggle()}}label:{Image(systemName:captions ? "captions.bubble.fill":"captions.bubble").font(.title3).frame(width:48,height:48)}.accessibilityLabel("Toggle transcript")
                    Button{if active{pause()}else{listen()}}label:{Image(systemName:active ? "pause.fill":"mic.fill").font(.title2).frame(width:64,height:64).foregroundStyle(active ? Design.background:Design.ink).background(active ? accent:Design.raised,in:Circle())}.accessibilityLabel(active ? "Pause":"Speak").accessibilityIdentifier("voice-listen")
                    Button(action:read){Image(systemName:"speaker.wave.2").font(.title3).frame(width:48,height:48)}.disabled(busy || speaker.preparing).accessibilityLabel(reply.isEmpty ? "Try the voice":"Listen to reply").accessibilityIdentifier("voice-read-reply")
                }.padding(.top,12).padding(.bottom,8)
                if speech.listening{Button("Send now",action:send).disabled(speech.transcript.isEmpty).font(.subheadline).frame(height:32)}
                if speaker.voiceNote?.hasPrefix("Offline backup") != true{Text(voiceName+" · Natural voice").font(.caption).foregroundStyle(Design.muted).padding(.bottom,16)}
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }.background(AppBackdrop(scope:scope)).foregroundStyle(Design.ink).preferredColorScheme(.dark)
        .animation(reducedMotion ? nil:.easeInOut(duration:0.28),value:hasResults)
        .onChange(of:entry?.id){_,_ in showingResults=true}
        .onDisappear{UIApplication.shared.isIdleTimerDisabled=false}
        .onAppear{UIApplication.shared.isIdleTimerDisabled=true;naturalVoice=true;speaker.refreshOutput();if !began{began=true;listen()}}
        .sheet(item:$proposal){action in if action.type == "gym"{GymChangeReview(action:action)}else{NativeAssistantReview(action:action,inCall:true)}}
        .sheet(item:$recordPreview){record in NavigationStack{NativeEditor(record:record)}}
        .sheet(isPresented:$settings){NavigationStack{Form{
            Section("Natural voice"){
                Picker("Voice",selection:$voiceName){Text("Aoede · Relaxed").tag("Aoede");Text("Puck · Upbeat").tag("Puck");Text("Kore · Clear").tag("Kore")}.pickerStyle(.navigationLink).accessibilityIdentifier("voice-choice")
                Button("Try the voice"){pause();read()}.accessibilityIdentifier("voice-preview")
                Text("Your chosen natural voice is used for replies. If its connection is blocked or reaches its limit, the reply stays on screen without switching voices.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Optional offline voice"){Toggle("Allow an offline backup",isOn:Binding(get:{speaker.allowOfflineVoice},set:{NativeVoicePreferences.defaults.set($0,forKey:"assistant-offline-voice")}));Text("Off by default. This uses an installed iOS voice only when you choose to allow it.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Sound"){HStack{Text(speaker.output.isEmpty ? "Audio output":speaker.output);Spacer();NativeOutputPicker().frame(width:32,height:32)};NativeVolumeControls().frame(height:32);if speaker.muted{Text("Raise the volume to hear your assistant.").font(.footnote)}}
        }.navigationTitle("Voice settings").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){settings=false}.accessibilityIdentifier("voice-settings-done")}}}.presentationDetents([.large]).presentationDragIndicator(.visible)}
    }
    var activity:some View{NativeVoiceVisual(level:active ? level:0,thinking:busy || speaker.preparing,color:activityColor,reducedMotion:reducedMotion || settings).accessibilityElement(children:.ignore).accessibilityLabel("Voice activity · "+status).accessibilityValue("Audio level "+String(Int(level*100))).accessibilityIdentifier("voice-activity")}

}
struct CaptureListeningVisual:View {
    let level:CGFloat
    let reducedMotion:Bool
    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/30,paused:reducedMotion)){timeline in
            let time=reducedMotion ? 0:timeline.date.timeIntervalSinceReferenceDate
            let energy=min(max(level,0),1)
            ZStack {
                ForEach(0..<3){layer in
                    let wave=sin(time*1.4+Double(layer)*1.8)
                    Ellipse().fill(Design.accent.opacity(0.08+Double(layer)*0.035))
                        .frame(width:155+CGFloat(layer)*20,height:150+CGFloat(layer)*14)
                        .rotationEffect(.degrees(wave*12+Double(layer)*60))
                        .scaleEffect(reducedMotion ? 1:1+energy*0.22+CGFloat(wave)*0.025)
                }
                Circle().fill(RadialGradient(colors:[Design.ink.opacity(0.22),Design.accent.opacity(0.28),Design.accent.opacity(0.07)],center:.init(x:0.35,y:0.3),startRadius:0,endRadius:80)).frame(width:145,height:145)
                    .scaleEffect(reducedMotion ? 1:1+energy*0.12)
                Circle().stroke(Design.ink.opacity(0.14),lineWidth:1).frame(width:145,height:145)
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }.accessibilityHidden(true)
    }
}

struct NativeVoiceVisual:View {
    let level:CGFloat
    let thinking:Bool
    let color:Color
    let reducedMotion:Bool
    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/30,paused:reducedMotion || (!thinking && level<0.001))){timeline in
            GeometryReader{geometry in
                let size=min(geometry.size.width,geometry.size.height)*0.74
                let time=reducedMotion ? 0:timeline.date.timeIntervalSinceReferenceDate
                ZStack{
                    Circle().fill(color.opacity(0.1)).blur(radius:size*0.08).padding(-size*0.03)
                    ForEach(0..<4){layer in
                        let wave=sin(time*(thinking ? 0.9:1.6)+Double(layer)*1.2)
                        Circle().stroke(AngularGradient(colors:[color.opacity(0.1),color.opacity(0.72),Design.ink.opacity(0.35),color.opacity(0.1)],center:.center,angle:.degrees(Double(layer)*45+wave*12)),lineWidth:CGFloat(2+layer))
                            .padding(CGFloat(layer)*size*0.055)
                            .scaleEffect(1+CGFloat(wave)*min(level,0.6)*0.055)
                    }
                    Circle().fill(RadialGradient(colors:[color.opacity(0.24),color.opacity(0.06),.clear],center:.init(x:0.4,y:0.35),startRadius:0,endRadius:size*0.42)).padding(size*0.14)
                    Circle().stroke(Design.ink.opacity(0.16),lineWidth:1).padding(size*0.17)
                    Ellipse().fill(Design.ink.opacity(0.06)).frame(width:size*0.48,height:size*0.23).blur(radius:12).offset(x:-size*0.06,y:-size*0.1)
                }.frame(width:size,height:size).frame(maxWidth:.infinity,maxHeight:.infinity)
            }
        }.accessibilityHidden(true)
    }
}

struct NativeVolumeControls:UIViewRepresentable {
    func makeUIView(context:Context)->MPVolumeView {let view=MPVolumeView();view.showsRouteButton=false;return view}
    func updateUIView(_ view:MPVolumeView,context:Context){}
}
struct NativeOutputPicker:UIViewRepresentable {
    func makeUIView(context:Context)->AVRoutePickerView {let view=AVRoutePickerView();view.tintColor=UIColor(Design.ink);view.activeTintColor = .systemBlue;return view}
    func updateUIView(_ view:AVRoutePickerView,context:Context){}
}
struct AudioWaveform:View {
    var levels:[CGFloat]
    var color:Color
    var height:CGFloat=64
    var body:some View {
        GeometryReader{proxy in
            Canvas{context,size in
                let samples=Array(levels.suffix(48));let count=max(1,samples.count);let step=size.width/48
                for (index,level) in samples.enumerated(){let height=max(3,min(size.height,level*size.height));let x=CGFloat(48-count+index)*step;let rect=CGRect(x:x,y:(size.height-height)/2,width:max(2,step-3),height:height);context.fill(Path(roundedRect:rect,cornerRadius:2),with:.color(color))}
            }
        }.frame(height:height).accessibilityHidden(true)
    }
}
@MainActor final class NativeMemoRecorder:NSObject,ObservableObject,AVAudioPlayerDelegate {
    @Published var recording=false
    @Published var requesting=false
    @Published var seconds:Double=0
    @Published var levels:[CGFloat]=[]
    @Published var clip:URL?
    @Published var playing=false
    @Published var message:String?
    private let audioID=UUID()
    private var permissionID=UUID()
    private var recorder:AVAudioRecorder?
    private var player:AVAudioPlayer?
    private var meter:Task<Void,Never>?
    func start(){
        guard !requesting,!recording else{return};discard();message=nil;requesting=true
        let id=UUID();permissionID=id
        AVAudioSession.sharedInstance().requestRecordPermission{allowed in Task{@MainActor in
            guard self.permissionID==id else{return};self.requesting=false
            guard allowed else{self.message="Enable microphone access in iPhone Settings to record a memo.";return}
            do {
                try NativeAudioSession.activate(self.audioID,category:.record,mode:.default)
                let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
                let recorder=try AVAudioRecorder(url:url,settings:[AVFormatIDKey:Int(kAudioFormatLinearPCM),AVSampleRateKey:24000,AVNumberOfChannelsKey:1,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false])
                recorder.isMeteringEnabled=true
                guard recorder.record() else{throw AssistantMedia.issue("The microphone couldn’t start.")}
                self.recorder=recorder;self.clip=url;self.recording=true;self.seconds=0;self.levels=[]
                self.meter=Task{@MainActor in while !Task.isCancelled,self.recording {
                    recorder.updateMeters();self.seconds=recorder.currentTime
                    self.levels.append(CGFloat(max(0,min(1,pow(10,recorder.averagePower(forChannel:0)/20)*3))));self.levels=Array(self.levels.suffix(48))
                    if self.seconds>=45{self.finish();return}
                    try? await Task.sleep(for:.milliseconds(100))
                }}
            }catch{NativeAudioSession.release(self.audioID);self.message=error.localizedDescription}
        }}
    }
    func finish(){guard recording else{return};seconds=recorder?.currentTime ?? seconds;recorder?.stop();recorder=nil;recording=false;meter?.cancel();meter=nil;NativeAudioSession.release(audioID)}
    func preview(){
        if playing{stopPreview();return};guard let clip,!recording else{return}
        do{try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio,onReplacement:{[weak self] in self?.stopPreview()});let player=try AVAudioPlayer(contentsOf:clip);player.delegate=self;player.volume=1;player.prepareToPlay();guard player.play() else{throw AssistantMedia.issue("This memo couldn’t play.")};self.player=player;playing=true}
        catch{NativeAudioSession.release(audioID);message=error.localizedDescription}
    }
    func stopPreview(){player?.stop();player=nil;playing=false;NativeAudioSession.release(audioID)}
    func attachment() throws -> AssistantAttachment {
        finish();stopPreview();guard let clip,seconds>0.2 else{throw AssistantMedia.issue("Record a little longer before attaching your memo.")}
        let bytes=try Data(contentsOf:clip);guard bytes.count<=AssistantMedia.limit else{throw AssistantMedia.issue("This memo is too large. Record a shorter one.")}
        return AssistantAttachment(name:"Voice memo · "+Date.now.formatted(.dateTime.hour().minute())+".wav",mimeType:"audio/wav",bytes:bytes)
    }
    func discard(){permissionID=UUID();requesting=false;finish();stopPreview();if let clip{try? FileManager.default.removeItem(at:clip)};clip=nil;seconds=0;levels=[]}
    nonisolated func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool){Task{@MainActor in guard self.player===player else{return};self.stopPreview();if !flag{self.message="Playback was interrupted. Try again."}}}
}
struct NativeMemoSheet:View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder=NativeMemoRecorder()
    let scope:String
    let attach:(AssistantAttachment)->Void
    var accent:Color{WorkspaceTheme.accent(scope)}
    var body:some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:22){
                Text(recorder.recording ? "Recording your thought…":recorder.clip == nil ? "Keep it in your own voice.":"Your memo is ready.").font(.title2.weight(.semibold))
                Text("Up to 45 seconds. Listen first, then attach it to your message.").font(.subheadline).foregroundStyle(Design.muted)
                VStack(spacing:16){AudioWaveform(levels:recorder.levels.isEmpty ? Array(repeating:0.035,count:48):recorder.levels,color:recorder.recording ? .red:accent);Text(Duration.seconds(recorder.seconds).formatted(.time(pattern:.minuteSecond))).font(.system(.title,design:.monospaced)).monospacedDigit().accessibilityIdentifier("memo-duration")}.padding(22).background(Design.surface,in:RoundedRectangle(cornerRadius:22))
                if let message=recorder.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
                HStack(spacing:16){
                    Button{if recorder.recording{recorder.finish()}else{recorder.start()}}label:{Label(recorder.recording ? "Stop":recorder.clip == nil ? "Record":"Record again",systemImage:recorder.recording ? "stop.fill":"mic.fill").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(ActionStyle()).tint(.red).disabled(recorder.requesting).accessibilityIdentifier("memo-record")
                    if recorder.clip != nil,!recorder.recording{Button{recorder.preview()}label:{Label(recorder.playing ? "Pause":"Play",systemImage:recorder.playing ? "pause.fill":"play.fill").frame(minHeight:48)}.buttonStyle(ActionStyle()).accessibilityIdentifier("memo-preview")}
                }
                if recorder.clip != nil,!recorder.recording{Button{do{let file=try recorder.attachment();attach(file);dismiss()}catch{recorder.message=error.localizedDescription}}label:{Label("Attach memo",systemImage:"plus.circle.fill").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(Design.background).accessibilityIdentifier("memo-attach")}
                Text("The recording stays on this phone until you send it to Gemini.").font(.caption).foregroundStyle(Design.muted)
                Spacer(minLength:0)
            }.padding(24).background(AppBackdrop(scope:scope)).navigationTitle("Voice memo").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}}
        }.preferredColorScheme(.dark).onDisappear{recorder.discard()}.onChange(of:scenePhase){_,phase in if phase == .background{recorder.finish();recorder.stopPreview()}}
    }
}

struct SongPreview:Codable,Identifiable {
    let id:String
    let title:String
    let artist:String
    let audioURL:String
    let storeURL:String
}
@MainActor final class NativeMusicPlayback:ObservableObject {
    static let shared=NativeMusicPlayback()
    private var autoPlayed:Set<UUID>=[]
    func shouldAutoplay(_ key:UUID?)->Bool{guard let key else{return true};guard !autoPlayed.contains(key) else{return false};if autoPlayed.count>100{autoPlayed.removeAll()};autoPlayed.insert(key);return true}
    @Published var track:SongPreview?
    @Published var player:PracticePlayer?
    func prepare(_ preview:SongPreview){
        guard track?.id != preview.id else{return}
        stop();guard let url=URL(string:preview.audioURL),url.scheme=="https" else{return}
        track=preview;player=PracticePlayer(url:url,maximumDuration:30)
    }
    func play(_ preview:SongPreview){prepare(preview);guard let player,!player.playing,!player.starting else{return};player.toggle()}
    func pause(){player?.player.pause();player?.playing=false;player?.starting=false}
    func stop(){player?.stop();player=nil;track=nil}
}
struct NativeSongPreview:View {
    let preview:SongPreview
    var beforePlayback:()->Void={}
    var autoPlay=false
    var playbackKey:UUID?
    @StateObject private var music=NativeMusicPlayback.shared
    @State private var started=false
    @Environment(\.scenePhase) private var phase
    var body:some View {
        VStack(alignment:.leading,spacing:12){
            Label("Apple preview · up to 30 seconds",systemImage:"music.note").font(.caption).foregroundStyle(Design.muted)
            Text(preview.title).font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
            Text(preview.artist).font(.subheadline).foregroundStyle(Design.muted)
            if music.track?.id==preview.id,let player=music.player{SongPreviewTransport(player:player,beforePlayback:beforePlayback)}else{Button("Play preview"){beforePlayback();music.play(preview)}.buttonStyle(ActionStyle())}
            if let url=URL(string:preview.storeURL),url.scheme=="https"{Link("Open in Apple Music",destination:url).font(.footnote)}
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:18))
        .onChange(of:phase){_,value in if value == .background{music.pause()}}
        .onAppear{guard !started else{return};started=true;if autoPlay,music.shouldAutoplay(playbackKey){beforePlayback();music.play(preview)}}
    }
}
struct SongPreviewTransport:View {
    @ObservedObject var player:PracticePlayer
    let beforePlayback:()->Void
    var body:some View {
        HStack{Button{beforePlayback();player.toggle()}label:{Label(player.playing || player.starting ? "Pause preview":"Play preview",systemImage:player.playing || player.starting ? "pause.fill":"play.fill")}.buttonStyle(ActionStyle());Spacer();Text("\(Int(player.seconds)) / \(Int(player.duration)) sec").font(.caption.monospacedDigit()).foregroundStyle(Design.muted)}
        if let message=player.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
    }
}

/// Capture records the complete thought before transcription; recognition hypotheses never replace its audio.
@MainActor final class NativeThoughtRecorder:ObservableObject {
    @Published var listening=false
    @Published var requesting=false
    @Published var transcript=""
    @Published var levels:[CGFloat]=[]
    @Published var message:String?
    @Published var recordingURL:URL?
    private var recorder:AVAudioRecorder?
    private var meter:Task<Void,Never>?
    private let audioID=UUID()
    private var permissionID=UUID()
    func toggle(){
        if listening{stop();return};guard !requesting else{return}
        requesting=true;message=nil;let id=UUID();permissionID=id
        AVAudioSession.sharedInstance().requestRecordPermission{allowed in Task{@MainActor in
            guard self.permissionID==id else{return};self.requesting=false
            guard allowed else{self.message="Enable microphone access in iPhone Settings to record your thought.";return}
            do{
                self.discard();self.transcript="";self.levels=[]
                try NativeAudioSession.activate(self.audioID,category:.record,mode:.measurement,onReplacement:{[weak self] in self?.stop()})
                let folder=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ThoughtRecordings",isDirectory:true)
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let url=folder.appendingPathComponent(UUID().uuidString+".m4a")
                let recorder=try AVAudioRecorder(url:url,settings:[AVFormatIDKey:Int(kAudioFormatMPEG4AAC),AVSampleRateKey:24000,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:48000])
                recorder.isMeteringEnabled=true;recorder.prepareToRecord()
                guard recorder.record() else{throw URLError(.cannotCreateFile)}
                self.recorder=recorder;self.recordingURL=url;self.listening=true
                self.meter=Task{@MainActor in while !Task.isCancelled,self.listening{recorder.updateMeters();let level=CGFloat(AudioMeter.level(decibels:recorder.averagePower(forChannel:0)));self.levels.append(level);if self.levels.count>48{self.levels.removeFirst(self.levels.count-48)};try? await Task.sleep(for:.milliseconds(40))}}
            }catch{self.stop();self.message="The recording couldn’t start. Your written thought is unchanged."}
        }}
    }
    func stop(){permissionID=UUID();requesting=false;meter?.cancel();meter=nil;recorder?.stop();recorder=nil;listening=false;NativeAudioSession.release(audioID)}
    func restore(_ path:String?){
        guard recordingURL==nil,let path else{return}
        let folder=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ThoughtRecordings",isDirectory:true).standardizedFileURL
        let url=URL(fileURLWithPath:path).standardizedFileURL
        guard url.deletingLastPathComponent()==folder,FileManager.default.fileExists(atPath:url.path) else{return}
        recordingURL=url;message="Your unfinished recording is ready to transcribe."
    }
    func discard(){stop();if let recordingURL{try? FileManager.default.removeItem(at:recordingURL)};recordingURL=nil}
    func finish() async -> String {
        stop();guard let url=recordingURL else{return transcript}
        do{
            if #available(iOS 26.0,*){
                message="Transcribing your complete thought…"
                transcript=try await ThoughtTranscription.read(url)
                message=transcript.isEmpty ? "No speech was detected. Your recording is kept so you can listen or try again.":nil
            }else{message="Complete thought transcription needs iOS 26 or later. Your recording is kept."}
            if !transcript.isEmpty{try? FileManager.default.removeItem(at:url);recordingURL=nil}
        }catch{if !Task.isCancelled{message="Your complete recording was kept. Retry transcription or save the audio before leaving Capture."}}
        return transcript
    }
}
@available(iOS 26.0,*) enum ThoughtTranscription {
    static func read(_ url:URL) async throws -> String {
        guard SpeechTranscriber.isAvailable,let locale=await SpeechTranscriber.supportedLocale(equivalentTo:Locale(identifier:"en-US")) else{throw URLError(.resourceUnavailable)}
        let transcriber=SpeechTranscriber(locale:locale,preset:.transcription)
        if let assets=try await AssetInventory.assetInstallationRequest(supporting:[transcriber]){try await assets.downloadAndInstall()}
        let analyzer=SpeechAnalyzer(modules:[transcriber])
        let collector=Task{var sections:[(Double,String)]=[];for try await result in transcriber.results{try Task.checkCancellation();let text=String(result.text.characters).trimmingCharacters(in:.whitespacesAndNewlines);if !text.isEmpty{sections.append((result.range.start.seconds,text))}};return sections.sorted{$0.0<$1.0}.map{$0.1}.joined(separator:" ")}
        do{let file=try AVAudioFile(forReading:url);_ = try await analyzer.analyzeSequence(from:file);try await analyzer.finalizeAndFinishThroughEndOfInput();return try await collector.value}
        catch{collector.cancel();await analyzer.cancelAndFinishNow();throw error}
    }
}

#if DEBUG
struct NativeRecordingDiagnostics:View {
    @State private var result="Checking…"
    var body:some View {VStack(spacing:20){Text("Recording and reader verification");Text(result).accessibilityIdentifier("recording-diagnostic-result")}.padding(24).task{
        guard #available(iOS 26.0,*) else{result="Needs iOS 26";return}
        do{
            var chapter=EdizCore.Record(space:"moshia",kind:"chapter",title:"Fixture chapter")
            chapter.body=String(repeating:"A quiet page contains an idea, a guitar and a decision. Unicode: café, 日本語 and 🎸.\n\n",count:80)
            let readerChecks=[16.0,20,28].allSatisfy{size in let pages=BookPagination.pages(chapter:chapter,width:320,height:470,fontSize:size);return pages.count>1 && pages.map(\.text).joined()==chapter.body}
            guard readerChecks else{result="Reader lost text";return}
            guard let url=Bundle.main.url(forResource:"learn-capture",withExtension:"m4a",subdirectory:"GuideAudio/Aoede") else{result="Missing fixture";return}
            let text=try await ThoughtTranscription.read(url)
            let normalized=text.lowercased()
            let beginning=normalized.contains("an idea usually arrives")
            let ending=normalized.contains("then save")
            result="Reader exact: yes; First: \(beginning); Last: \(ending); Words: \(text.split(whereSeparator:{$0.isWhitespace}).count)"
        }catch{result="Transcription error: "+error.localizedDescription}
    }}
}
#endif
