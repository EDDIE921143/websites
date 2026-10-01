import SwiftUI
import AVFoundation
import Speech
import QuickLook
import EdizCore

@MainActor final class NativeSpeech:ObservableObject {
    @Published var listening=false
    @Published var requesting=false
    @Published var transcript=""
    @Published var message:String?
    private let engine=AVAudioEngine()
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var task:SFSpeechRecognitionTask?
    private var tapInstalled=false
    func toggle(){if listening || requesting{stop();return};requesting=true;message=nil
        SFSpeechRecognizer.requestAuthorization{status in Task{@MainActor in guard self.requesting else{return};guard status == .authorized else{self.requesting=false;self.message="Speech permission wasn’t granted. You can still type your capture.";return};AVAudioSession.sharedInstance().requestRecordPermission{granted in Task{@MainActor in guard self.requesting else{return};guard granted else{self.requesting=false;self.message="Microphone access wasn’t granted. You can still type.";return};self.start()}}}}
    }
    private func start(){
        guard let recognizer=SFSpeechRecognizer(locale:.current),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{requesting=false;message="On-device transcription isn’t available for this language. Use the keyboard or change your speech language.";return}
        do{stop();transcript="";let session=AVAudioSession.sharedInstance();try session.setCategory(.record,mode:.measurement,options:.duckOthers);try session.setActive(true,options:.notifyOthersOnDeactivation);let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;self.request=request;let input=engine.inputNode;let format=input.outputFormat(forBus:0);input.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in request.append(buffer)};tapInstalled=true;engine.prepare();try engine.start();listening=true;requesting=false;task=recognizer.recognitionTask(with:request){result,error in Task{@MainActor in if let result{self.transcript=result.bestTranscription.formattedString};if error != nil || result?.isFinal == true{self.stop()}}}}catch{stop();message="The microphone couldn’t start. Your text is still here."}
    }
    func stop(){requesting=false;engine.stop();if tapInstalled{engine.inputNode.removeTap(onBus:0);tapInstalled=false};request?.endAudio();task?.cancel();request=nil;task=nil;listening=false;try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)}
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
    @Published var speed:Float=1
    @Published var loopStart=0.0
    @Published var loopEnd=0.0
    @Published var looping=false
    @Published var message:String?
    let player:AVPlayer
    private var observer:Any?
    init(url:URL){let item=AVPlayerItem(url:url);item.audioTimePitchAlgorithm = .spectral;player=AVPlayer(playerItem:item);observer=player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.1,preferredTimescale:600),queue:.main){[weak self] time in Task{@MainActor in guard let self else{return};self.seconds=time.seconds.isFinite ? time.seconds:0;if self.looping && self.loopEnd>self.loopStart && self.seconds>=self.loopEnd{self.seek(self.loopStart)}else if self.duration>0 && self.seconds>=self.duration{self.playing=false}}}
        Task{do{let length=try await item.asset.load(.duration).seconds;duration=length.isFinite ? length:0;loopEnd=duration}catch{message="This audio file could not be opened."}}
    }
    func toggle(){if playing{player.pause();playing=false}else{try? AVAudioSession.sharedInstance().setCategory(.playback,mode:.default);try? AVAudioSession.sharedInstance().setActive(true);player.playImmediately(atRate:speed);playing=true}}
    func seek(_ seconds:Double){player.seek(to:CMTime(seconds:seconds,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)}
    func stop(){player.pause();playing=false;if let observer{player.removeTimeObserver(observer);self.observer=nil}}
}
struct NativeAudioPractice:View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio:PracticePlayer
    init(url:URL){_audio=StateObject(wrappedValue:PracticePlayer(url:url))}
    var body:some View {
        NavigationStack{Form{Section("Playback"){if let message=audio.message{Text(message)};Slider(value:Binding(get:{audio.seconds},set:{audio.seek($0)}),in:0...max(1,audio.duration));HStack{Text(audio.seconds,format:.number.precision(.fractionLength(0)));Spacer();Text(audio.duration,format:.number.precision(.fractionLength(0)))}.font(.caption).foregroundStyle(Design.muted);Button(audio.playing ? "Pause":"Play"){audio.toggle()};Picker("Speed",selection:$audio.speed){Text("0.5×").tag(Float(0.5));Text("0.75×").tag(Float(0.75));Text("1×").tag(Float(1));Text("1.25×").tag(Float(1.25))}.onChange(of:audio.speed){_,speed in if audio.playing{audio.player.rate=speed}};Text("Slower playback preserves pitch.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Section loop"){Toggle("Loop section",isOn:$audio.looping);Button("Set start here · \(Int(audio.loopStart))s"){audio.loopStart=min(audio.seconds,max(0,audio.loopEnd-0.2))};Button("Set end here · \(Int(audio.loopEnd))s"){audio.loopEnd=max(audio.seconds,audio.loopStart+0.2)}}
        }.scrollContentBackground(.hidden).background(Design.background).navigationTitle("Practice").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){audio.stop();dismiss()}}}}.onDisappear{audio.stop()}
    }
}
@MainActor final class NativeMetronome:ObservableObject {
    @Published var bpm=100
    @Published var playing=false
    @Published var message:String?
    private let engine=AVAudioEngine()
    private let player=AVAudioPlayerNode()
    private let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    init(){engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:format)}
    func toggle(){if playing{stop();return};message=nil
        do {let session=AVAudioSession.sharedInstance();try session.setCategory(.playback,mode:.default);try session.setActive(true);let samples=BeatAudio.samples(bpm:bpm);guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(samples.count)),let channel=buffer.floatChannelData?[0] else{throw CoreError.database("audio buffer unavailable")};buffer.frameLength=AVAudioFrameCount(samples.count);for index in samples.indices{channel[index]=samples[index]};player.scheduleBuffer(buffer,at:nil,options:.loops);try engine.start();player.play();playing=engine.isRunning && player.isPlaying;if !playing{throw CoreError.database("audio output unavailable")}}
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
        VStack(alignment:.leading,spacing:24){HStack{Text("CLEARANCE 19").font(.subheadline).foregroundStyle(Design.muted);Spacer();Button("Close"){metronome.stop();dismiss()}};if songs.indices.contains(index){let song=songs[index];Text("\(index+1) of \(songs.count)").font(.subheadline).foregroundStyle(Design.muted);Text(song.title).font(.largeTitle.weight(.medium));Text([song.data["BPM"].map{"\($0) BPM"},song.data["tuning"]].compactMap{$0}.joined(separator:" · ")).font(.title3);ScrollView{Text(song.data["structure"] ?? song.body).font(.body).frame(maxWidth:.infinity,alignment:.leading)};HStack{Button("Previous"){index=max(0,index-1)}.buttonStyle(ActionStyle()).disabled(index == 0);Button("Next"){index=min(songs.count-1,index+1)}.buttonStyle(ActionStyle(primary:true)).disabled(index>=songs.count-1)};Stepper("\(metronome.bpm) BPM",value:$metronome.bpm,in:30...240);Button(metronome.playing ? "Stop metronome":"Start metronome"){metronome.toggle()}.buttonStyle(ActionStyle());if let message=metronome.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}}else{Text("Add songs to your setlist first.")}}
            .padding(24).background(Design.background).preferredColorScheme(.dark).simultaneousGesture(DragGesture(minimumDistance:50).onEnded{value in guard abs(value.translation.width)>abs(value.translation.height)*1.5 else{return};index=value.translation.width<0 ? min(max(0,songs.count-1),index+1):max(0,index-1)})
            .onAppear{applySongTempo()}.onChange(of:index){_,_ in applySongTempo()}.onChange(of:metronome.bpm){_,_ in metronome.changeBPM()}.onDisappear{metronome.stop()}
    }
}
