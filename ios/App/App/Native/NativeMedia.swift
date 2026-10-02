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

@MainActor enum NativeAudioSession {
    private static var owner:UUID?
    static func activate(_ id:UUID,category:AVAudioSession.Category,mode:AVAudioSession.Mode) throws {
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(category,mode:mode,options:category == .record ? []:.duckOthers)
        try session.setActive(true);owner=id
    }
    static func release(_ id:UUID){guard owner==id else{return};owner=nil;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
}
@MainActor final class NativeSpeech:ObservableObject {
    @Published var listening=false
    @Published var requesting=false
    @Published var transcript=""
    @Published var level:CGFloat=0
    @Published var message:String?
    private let audioID=UUID()
    private var recognitionID=UUID()
    private let engine=AVAudioEngine()
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var task:SFSpeechRecognitionTask?
    private var tapInstalled=false
    func toggle(){if listening || requesting{stop();return};requesting=true;message=nil
        SFSpeechRecognizer.requestAuthorization{status in Task{@MainActor in guard self.requesting else{return};guard status == .authorized else{self.requesting=false;self.message="Speech permission wasn’t granted. You can still type your capture.";return};AVAudioSession.sharedInstance().requestRecordPermission{granted in Task{@MainActor in guard self.requesting else{return};guard granted else{self.requesting=false;self.message="Microphone access wasn’t granted. You can still type.";return};self.start()}}}}
    }
    private func start(){
        guard let recognizer=SFSpeechRecognizer(locale:.current),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{requesting=false;message="On-device transcription isn’t available for this language. Use the keyboard or change your speech language.";return}
        do{stop();transcript="";try NativeAudioSession.activate(audioID,category:.record,mode:.measurement);let recognitionID=UUID();self.recognitionID=recognitionID;let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;self.request=request;let input=engine.inputNode;let format=input.outputFormat(forBus:0);input.installTap(onBus:0,bufferSize:1024,format:format){[weak self] buffer,_ in
            request.append(buffer)
            if let channel=buffer.floatChannelData?[0]{let count=min(Int(buffer.frameLength),512);var sum:Float=0;for i in 0..<count{sum+=channel[i]*channel[i]};let value=CGFloat(min(1,sqrt(sum/Float(max(1,count)))*4));Task{@MainActor in guard self?.recognitionID==recognitionID else{return};self?.level=value}}
        };tapInstalled=true;engine.prepare();try engine.start();listening=true;requesting=false;task=recognizer.recognitionTask(with:request){result,error in Task{@MainActor in guard self.recognitionID==recognitionID else{return};if let result{self.transcript=result.bestTranscription.formattedString};if let error,self.listening,result?.isFinal != true{self.message="Transcription stopped: "+error.localizedDescription};if error != nil || result?.isFinal == true{self.stop()}}}}catch{stop();message="The microphone couldn’t start. Your text is still here."}
    }
    func stop(){recognitionID=UUID();requesting=false;engine.stop();if tapInstalled{engine.inputNode.removeTap(onBus:0);tapInstalled=false};request?.endAudio();task?.cancel();request=nil;task=nil;listening=false;level=0;NativeAudioSession.release(audioID)}
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
    let player:AVPlayer
    private var observer:Any?
    private var statusObserver:NSKeyValueObservation?
    init(url:URL){let item=AVPlayerItem(url:url);item.audioTimePitchAlgorithm = .spectral;player=AVPlayer(playerItem:item);observer=player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.1,preferredTimescale:600),queue:.main){[weak self] time in Task{@MainActor in guard let self else{return};self.seconds=time.seconds.isFinite ? time.seconds:0;if self.looping && self.loopEnd>self.loopStart && self.seconds>=self.loopEnd{self.seek(self.loopStart)}else if self.duration>0 && self.seconds>=self.duration{self.playing=false}}}
        statusObserver=player.observe(\.timeControlStatus,options:[.new]){[weak self] player,_ in let state=player.timeControlStatus;Task{@MainActor in guard let self else{return};self.playing=state == .playing;if state == .playing{self.starting=false};if player.currentItem?.status == .failed{self.starting=false;self.message="This audio file couldn’t be played."}}}
        Task{do{let length=try await item.asset.load(.duration).seconds;duration=length.isFinite ? length:0;loopEnd=duration}catch{message="This audio file could not be opened."}}
    }
    func toggle(){
        if playing || starting {player.pause();playing=false;starting=false;return}
        guard duration>0 else{message="This audio file isn’t ready to play yet.";return}
        do {message=nil;try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default);try AVAudioSession.sharedInstance().setActive(true);starting=true;player.playImmediately(atRate:speed)}
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
    @Published var bpm=100
    @Published var playing=false
    @Published var startedAt=Date()
    @Published var message:String?
    private let engine=AVAudioEngine()
    private let player=AVAudioPlayerNode()
    private let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    init(){engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:format)}
    func toggle(){if playing{stop();return};message=nil
        do {let session=AVAudioSession.sharedInstance();try session.setCategory(.playback,mode:.default);try session.setActive(true);let samples=BeatAudio.samples(bpm:bpm);guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)),let channel=buffer.floatChannelData?[0] else{throw CoreError.database("audio buffer unavailable")};buffer.frameLength=AVAudioFrameCount(samples.count);for index in samples.indices{channel[index]=samples[index]};player.scheduleBuffer(buffer,at:nil,options:.loops);try engine.start();player.play();startedAt=Date();playing=engine.isRunning && player.isPlaying;if !playing{throw CoreError.database("audio output unavailable")}}
        catch {stop();message="Sound couldn’t start. Check the audio output and try again."}
    }
    func changeBPM(){if playing{stop();toggle()}}
    func stop(){player.stop();engine.stop();playing=false;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
}
struct NativeRehearsal:View {
    @Environment(\.dismiss) private var dismiss
    let songs:[EdizCore.Record]
    @State private var index=0
    @StateObject private var metronome=NativeMetronome()
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
                    HStack(spacing:12){ForEach(0..<4,id:\.self){number in Capsule().fill(metronome.playing && beat == number ? Design.ink:Design.raised).frame(width:number == 0 ? 26:12,height:12)}}.frame(maxWidth:.infinity).accessibilityLabel(metronome.playing ? "Beat \(beat+1) of 4":"Metronome stopped")
                }
                HStack {Text("\(metronome.bpm)").font(Design.font(28)).monospacedDigit();Text("BPM").font(.caption).foregroundStyle(Design.muted);Spacer();Stepper("Tempo",value:$metronome.bpm,in:30...240).labelsHidden().accessibilityLabel("Metronome tempo")}
                HStack(spacing:12) {
                    if !songs.isEmpty {Button {index=max(0,index-1)} label:{Image(systemName:"backward.end.fill").frame(width:20)}.buttonStyle(ActionStyle()).disabled(index == 0).accessibilityLabel("Previous")}
                    Button(metronome.playing ? "Stop metronome":"Start metronome"){metronome.toggle()}.buttonStyle(ActionStyle()).frame(maxWidth:.infinity)
                    if !songs.isEmpty {Button {index=min(songs.count-1,index+1)} label:{Image(systemName:"forward.end.fill").frame(width:20)}.buttonStyle(ActionStyle()).disabled(index>=songs.count-1).accessibilityLabel("Next")}
                }
                if let message=metronome.message {Text(message).font(.footnote).foregroundStyle(Design.muted)}
            }.padding(20).background(AppBackdrop())
        }
        .background(AppBackdrop()).foregroundStyle(Design.ink).preferredColorScheme(.dark)
        .simultaneousGesture(DragGesture(minimumDistance:50).onEnded{value in guard abs(value.translation.width)>abs(value.translation.height)*1.5 else{return};index=value.translation.width<0 ? min(max(0,songs.count-1),index+1):max(0,index-1)})
        .onAppear{applySongTempo()}.onChange(of:index){_,_ in applySongTempo()}.onChange(of:metronome.bpm){_,_ in metronome.changeBPM()}.onDisappear{metronome.stop()}
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
        if type.conforms(to:.audio),url.pathExtension.lowercased()=="wav"{return .init(name:String(url.lastPathComponent.prefix(180)),mimeType:"audio/wav",bytes:data)}
        if type.conforms(to:.pdf){return .init(name:name,mimeType:"application/pdf",bytes:data)}
        if type.conforms(to:.text)||["txt","md","csv","json"].contains(url.pathExtension.lowercased()),String(data:data,encoding:.utf8) != nil {return .init(name:name,mimeType:"text/plain",bytes:data)}
        throw issue("Use a photo, short video, PDF, or a text, Markdown, CSV or JSON file.")
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
@MainActor final class NativeAssistantSpeaker:NSObject,ObservableObject,AVSpeechSynthesizerDelegate,AVAudioPlayerDelegate {
    @Published var speaking=false
    @Published var preparing=false
    @Published var voiceNote:String?
    @Published var level:CGFloat=0
    @Published var output="iPhone"
    @Published var muted=false
    private let audioID=UUID()
    private var meter:Task<Void,Never>?
    private var utterance:AVSpeechUtterance?
    private var player:AVAudioPlayer?
    private var generation:Task<Void,Never>?
    private let synthesizer=AVSpeechSynthesizer()
    var finished:(()->Void)?
    override init(){super.init();synthesizer.delegate=self}
    func say(_ text:String,token:String?=nil,natural:Bool=true){
        stop();voiceNote=nil
        guard natural,let token,!text.isEmpty else{deviceSay(text);return}
        preparing=true
        generation=Task{@MainActor in
            do {
                var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!)
                request.httpMethod="POST";request.timeoutInterval=12
                request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
                request.httpBody=try JSONSerialization.data(withJSONObject:["mode":"speech","text":String(text.prefix(2000)),"voice":"Aoede"])
                let (data,response)=try await URLSession.shared.data(for:request)
                try Task.checkCancellation()
                guard let response=response as? HTTPURLResponse,response.statusCode==200,
                    let json=try JSONSerialization.jsonObject(with:data) as? [String:Any],let encoded=json["audio"] as? String,let audio=Data(base64Encoded:encoded) else{throw URLError(.cannotParseResponse)}
                try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio)
                let audioPlayer=try AVAudioPlayer(data:audio);audioPlayer.delegate=self;audioPlayer.volume=1;audioPlayer.isMeteringEnabled=true;audioPlayer.prepareToPlay();player=audioPlayer
                guard audioPlayer.play() else{throw URLError(.cannotDecodeContentData)}
                preparing=false;speaking=true;voiceNote="Natural voice · Gemini";monitorOutput()
            }catch {
                guard !Task.isCancelled else{return}
                preparing=false;voiceNote="Using device voice while natural voice is unavailable.";deviceSay(text)
            }
        }
    }
    private func deviceSay(_ text:String){
        do{try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio)}catch{voiceNote="Audio couldn’t start. Check your output and try again.";return}
        let utterance=AVSpeechUtterance(string:String(text.prefix(5000)));let recognizer=NLLanguageRecognizer();recognizer.processString(text)
        let language=recognizer.dominantLanguage?.rawValue ?? Locale.current.language.languageCode?.identifier ?? "en"
        let voices=AVSpeechSynthesisVoice.speechVoices().filter{$0.language.hasPrefix(language)}
        utterance.voice=voices.max{left,right in left.quality.rawValue < right.quality.rawValue} ?? AVSpeechSynthesisVoice(language:language)
        utterance.rate=AVSpeechUtteranceDefaultSpeechRate * 0.94;utterance.pitchMultiplier=1.0;utterance.preUtteranceDelay=0.08
        self.utterance=utterance;speaking=true;monitorOutput();synthesizer.speak(utterance)
    }
    func refreshOutput(){let session=AVAudioSession.sharedInstance();output=session.currentRoute.outputs.map(\.portName).joined(separator:", ");muted=session.outputVolume<0.01}
    private func monitorOutput(){
        meter?.cancel()
        meter=Task{@MainActor in while !Task.isCancelled,speaking {
            let session=AVAudioSession.sharedInstance();output=session.currentRoute.outputs.map(\.portName).joined(separator:", ");muted=session.outputVolume<0.01
            if let player{player.updateMeters();level=CGFloat(max(0,min(1,pow(10,player.averagePower(forChannel:0)/20))))}
            else{level=0.2}
            try? await Task.sleep(for:.milliseconds(100))
        }}
    }
    func stop(){generation?.cancel();generation=nil;meter?.cancel();meter=nil;preparing=false;player?.stop();player=nil;utterance=nil;speaking=false;level=0;synthesizer.stopSpeaking(at:.immediate);NativeAudioSession.release(audioID)}
    nonisolated func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool){Task{@MainActor in guard self.player===player else{return};self.stop();if !flag{self.voiceNote="Audio was interrupted. Tap Listen to try again."};self.finished?()}}
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player:AVAudioPlayer,error:Error?){Task{@MainActor in guard self.player===player else{return};self.stop();self.voiceNote="This audio couldn’t be played. Try Device voice."}}
    nonisolated func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didFinish utterance:AVSpeechUtterance){Task{@MainActor in guard self.utterance===utterance else{return};self.stop();self.finished?()}}

}
struct NativeAssistantVoicePanel:View {
    @AppStorage("assistant-natural-voice") private var naturalVoice=true
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @ObservedObject var speech:NativeSpeech
    @ObservedObject var speaker:NativeAssistantSpeaker
    let busy:Bool
    let reply:String
    let error:String?
    let scope:String
    let listen:()->Void
    let pause:()->Void
    let send:()->Void
    let read:()->Void
    let end:()->Void
    var accent:Color{WorkspaceTheme.accent(scope)}
    var status:String{speaker.preparing ? "Preparing natural voice…":busy ? "Thinking…":speaker.speaking ? "Your assistant is speaking":speech.listening ? "Listening to you":"Ready when you are"}
    var active:Bool{speaker.speaking || speech.listening}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:20){
                    Text(scope == "all" ? "Everyday":Catalog.space(scope).name).font(.title2.weight(.semibold))
                    Text("Voice conversation").font(.subheadline).foregroundStyle(Design.muted)
                    ZStack {
                        Circle().fill(accent.opacity(0.08));Circle().strokeBorder(accent.opacity(0.20),lineWidth:1)
                        if active {
                            let level=speaker.speaking ? speaker.level:speech.level
                            AudioWaveform(levels:(0..<48).map{index in max(0.025,level*(0.45+0.55*abs(sin(CGFloat(index)*0.42))))},color:accent).padding(26)
                        }else if busy || speaker.preparing{ProgressView().controlSize(.large).tint(accent)}
                        else{Image(systemName:"waveform").font(.system(size:42,weight:.light)).foregroundStyle(accent)}
                    }.frame(width:174,height:174).padding(.vertical,8).accessibilityElement(children:.ignore).accessibilityLabel("Voice activity").accessibilityValue("Audio level "+String(Int((speaker.speaking ? speaker.level:speech.level)*100))).accessibilityIdentifier("voice-activity")
                    Text(status).font(.headline).multilineTextAlignment(.center)
                    Picker("Voice",selection:$naturalVoice){Text("Natural").tag(true);Text("Device · faster").tag(false)}.pickerStyle(.segmented).disabled(speaker.speaking || speaker.preparing || speech.listening)
                    if !reply.isEmpty || !speech.transcript.isEmpty {
                        VStack(alignment:.leading,spacing:8){Text(speech.listening ? "YOU":"LATEST REPLY").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(accent);ScrollView{Text(speech.listening || busy ? speech.transcript:reply).font(.subheadline).lineSpacing(3).frame(maxWidth:.infinity,alignment:.leading)}}.frame(maxHeight:150).padding(18).background(Design.surface,in:RoundedRectangle(cornerRadius:20))
                    }
                    if let message=error ?? speech.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
                    if let note=speaker.voiceNote{Text(note).font(.caption).foregroundStyle(Design.muted)}
                    VStack(alignment:.leading,spacing:8){
                        HStack{Label(speaker.output.isEmpty ? "Audio output":speaker.output,systemImage:"speaker.wave.2").font(.caption).foregroundStyle(Design.muted);Spacer();NativeOutputPicker().frame(width:32,height:32).accessibilityLabel("Choose audio output")}
                        NativeVolumeControls().frame(height:32).accessibilityLabel("Playback volume")
                        if speaker.muted{Text("Volume is at zero. Raise it to hear your assistant.").font(.caption).foregroundStyle(accent)}
                    }.padding(16).background(Design.surface.opacity(0.9),in:RoundedRectangle(cornerRadius:18))
                    Button{read()}label:{Label(reply.isEmpty ? "Try the voice":"Listen to reply",systemImage:"speaker.wave.2.fill").font(.subheadline)}.disabled(busy || speaker.preparing).accessibilityIdentifier("voice-read-reply")
                }.padding(.horizontal,24).padding(.top,12).padding(.bottom,20)
            }.safeAreaInset(edge:.bottom){
                HStack(spacing:16){
                    Button{if speech.listening{pause()}else{listen()}}label:{Label(speech.listening ? "Pause mic":"Speak",systemImage:speech.listening ? "mic.slash.fill":"mic.fill").frame(maxWidth:.infinity,minHeight:54)}.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(Design.background).disabled(busy || speaker.preparing).accessibilityIdentifier("voice-listen")
                    if speech.listening{Button("Send now"){send()}.buttonStyle(.bordered).disabled(speech.transcript.isEmpty)}
                    Button{end()}label:{Image(systemName:"phone.down.fill").font(.title3).frame(width:54,height:54).foregroundStyle(.white).background(Color(red:0.80,green:0.23,blue:0.29),in:Circle())}.accessibilityLabel("End conversation")
                }.padding(.horizontal,24).padding(.top,12).padding(.bottom,14).background(.ultraThinMaterial)
            }.background{AppBackdrop(scope:scope).overlay(Color.black.opacity(0.18))}.navigationTitle("Your assistant").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){end()}.accessibilityIdentifier("voice-done")}}
        }.preferredColorScheme(.dark).onAppear{speaker.refreshOutput()}
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
    var body:some View {
        GeometryReader{proxy in
            Canvas{context,size in
                let samples=Array(levels.suffix(48));let count=max(1,samples.count);let step=size.width/48
                for (index,level) in samples.enumerated(){let height=max(3,min(size.height,level*size.height));let x=CGFloat(48-count+index)*step;let rect=CGRect(x:x,y:(size.height-height)/2,width:max(2,step-3),height:height);context.fill(Path(roundedRect:rect,cornerRadius:2),with:.color(color))}
            }
        }.frame(height:64).accessibilityHidden(true)
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
        do{try NativeAudioSession.activate(audioID,category:.playback,mode:.spokenAudio);let player=try AVAudioPlayer(contentsOf:clip);player.delegate=self;player.volume=1;player.prepareToPlay();guard player.play() else{throw AssistantMedia.issue("This memo couldn’t play.")};self.player=player;playing=true}
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
