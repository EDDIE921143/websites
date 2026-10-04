import SwiftUI
import EdizCore

enum RecordAssistTool:String,CaseIterable,Identifiable {
    case polish,summary,plan,review
    var id:String{rawValue}
    var title:String{switch self{case .polish:return "Clarify notes";case .summary:return "Summarize";case .plan:return "Next steps";case .review:return "Questions"}}
    var symbol:String{switch self{case .polish:return "pencil.line";case .summary:return "text.alignleft";case .plan:return "list.bullet.clipboard";case .review:return "questionmark.bubble"}}
    var detail:String{switch self{case .polish:return "Clearer writing, with your meaning kept.";case .summary:return "The important details in a short overview.";case .plan:return "Suggested steps based on this item.";case .review:return "Unclear points and questions worth resolving."}}
}
struct NativeRecordAssist:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    var closeAfterApply=true
    var onToolSelected:((RecordAssistTool)->Void)?=nil
    let record:EdizCore.Record
    let apply:(String,Bool)->Void
    @State private var tool:RecordAssistTool = .polish
    @State private var result=""
    @State private var error:String?
    @State private var busy=false
    @State private var job:Task<Void,Never>?
    @State private var requestID=UUID()
    @StateObject private var speaker=NativeAssistantSpeaker()
    var body:some View {
        NavigationStack{ScrollView{VStack(alignment:.leading,spacing:20){
            VStack(alignment:.leading,spacing:8){Text(record.title).font(.title2.weight(.medium)).fixedSize(horizontal:false,vertical:true);Text("Work with this item, one useful step at a time.").font(.subheadline).foregroundStyle(Design.muted)}
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10){ForEach(RecordAssistTool.allCases){choice in
                Button{cancel();tool=choice;result="";error=nil;onToolSelected?(choice)}label:{VStack(alignment:.leading,spacing:9){Label(choice.title,systemImage:choice.symbol).font(.subheadline.weight(.semibold));Text(choice.detail).font(.caption).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)}.frame(maxWidth:.infinity,minHeight:92,alignment:.topLeading).padding(14).foregroundStyle(Design.ink).background(tool == choice ? Design.raised:Design.surface,in:RoundedRectangle(cornerRadius:16)).overlay{RoundedRectangle(cornerRadius:16).stroke(tool == choice ? WorkspaceTheme.accent(record.space).opacity(0.65):.clear,lineWidth:1)}}.buttonStyle(.plain).accessibilityIdentifier("record-ai-tool-"+choice.id)
            }}
            Text(store.isPractice ? "Practice examples use a sample idea. No API request is made and your real records are untouched.":"Only this item’s title, notes and details are shared with your connected assistant. Nothing is changed until you choose to use the result and save.").font(.caption).foregroundStyle(Design.muted)
            if busy{HStack{ProgressView();Text("Working on your "+tool.title.lowercased()+"…").font(.subheadline);Spacer();Button("Stop"){cancel()}}.padding(16).background(Design.surface,in:RoundedRectangle(cornerRadius:16))}else{Button{run()}label:{Label(result.isEmpty ? tool.title:"Try again",systemImage:"sparkles").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(ActionStyle()).accessibilityIdentifier("record-ai-run")}
            if let error{Text(error).font(.subheadline).foregroundStyle(Design.muted).accessibilityIdentifier("record-ai-error")}
            if !result.isEmpty{
                Surface{VStack(alignment:.leading,spacing:16){Text(tool.title).font(.headline);Text(result).font(.body).lineSpacing(5).fixedSize(horizontal:false,vertical:true).textSelection(.enabled).accessibilityIdentifier("record-ai-result");HStack{Button{UIPasteboard.general.string=result}label:{Label("Copy",systemImage:"doc.on.doc")};Spacer();if !store.isPractice{Button{if speaker.speaking || speaker.preparing{speaker.stop()}else{speaker.say(result,token:store.assistantToken,natural:true,voice:NativeVoicePreferences.defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede")}}label:{Label(speaker.speaking || speaker.preparing ? "Stop reading":"Read aloud",systemImage:speaker.speaking || speaker.preparing ? "stop.fill":"speaker.wave.2")}}}.font(.caption);if let note=speaker.voiceNote{Text(note).font(.caption).foregroundStyle(Design.muted)}}}
                Button{apply(result,tool == .polish);store.walkthrough?.event("record-ai-applied");if closeAfterApply{dismiss()}}label:{Label(tool == .polish ? "Use these notes":"Add to notes",systemImage:"pencil").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(ActionStyle()).accessibilityIdentifier("record-ai-apply")
                Text("This updates the editor’s draft. Save the item when you’re ready.").font(.caption).foregroundStyle(Design.muted)
            }
        }.padding(20)}.background(AppBackdrop()).navigationTitle("Work with AI").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){cancel();dismiss()}}}}
        .environment(\.edizWorkspaceFocus,record.space).onDisappear{cancel();speaker.stop()}
    }
    func cancel(){requestID=UUID();job?.cancel();job=nil;busy=false;speaker.stop()}
    func run(){
        cancel();error=nil
        if tool == .polish,record.body.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{error="Add a few notes first. Clarify improves your own words.";return}
        if store.isPractice{
            switch tool{
            case .polish:result="After finishing my homework, I may record a guitar idea. Friday’s rehearsal still needs confirmation from the band."
            case .summary:result="The idea is to record guitar after homework. That depends on finishing the homework first. Friday rehearsal is unconfirmed."
            case .plan:result="Suggested next steps\n\n1. Finish the homework before considering recording.\n2. If there is time, record the guitar idea.\n3. Ask the band about Friday before making a commitment."
            case .review:result="Questions to resolve\n\nWhat homework must be finished first?\nWhat part of the guitar idea would you like to record?\nWho needs to confirm Friday’s rehearsal?"
            };return
        }
        guard let token=store.assistantToken else{error="Connect your assistant in Settings to use these tools. Your notes are still available to edit.";return}
        let id=UUID();requestID=id;busy=true;let selected=tool
        job=Task{@MainActor in
            defer{if requestID==id{busy=false}}
            do{
                let answer=try await GeminiAssistant.answer(question:"Work only on this selected item. "+selected.detail,records:[record],conversation:[],token:token,scope:record.space,requestMode:"record-"+selected.id)
                guard !Task.isCancelled,requestID==id else{return}
                guard !answer.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw URLError(.cannotParseResponse)}
                result=answer.text
            }catch{if !Task.isCancelled,requestID==id{self.error=error.localizedDescription}}
        }
    }
}

struct NativeAIWorkshop:View {
    var narrationEnabled=true
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var muted=false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var practice=NativeStore(practice:true)
    @StateObject private var narrator=NativeAssistantSpeaker()
    @State private var visited:Set<String>=["polish"]
    @State private var applied=false
    @State private var notes=""
    var example:EdizCore.Record{var item=EdizCore.Record(space:"personal",kind:"idea",title:"A guitar idea after homework");item.body="Uh, maybe after homework is finished I can record my guitar idea. Need to ask the band about Friday, not promise it yet.";return item}
    var body:some View {
        NavigationStack{VStack(spacing:0){
            HStack(spacing:12){Image(systemName:applied ? "star.circle.fill":"sparkles").font(.title).foregroundStyle(Design.accent);VStack(alignment:.leading,spacing:4){Text(applied ? "You kept the choice.":"Try the AI notes lab").font(.headline);Text(applied ? "Reviewed · Applied to a practice draft":"\(visited.count) of 4 tools explored · Sample data").font(.caption).foregroundStyle(Design.muted)};Spacer();Button{narrator.stop();dismiss()}label:{Image(systemName:"xmark").frame(width:44,height:44)}.accessibilityLabel("Leave notes lab")}.padding(16).background(Design.raised)
            if narrationEnabled{HStack{Button{muted.toggle();if muted{narrator.stop()}else{play("intro-ai-lab")}}label:{Label(muted ? "Unmute guide":"Mute guide",systemImage:muted ? "speaker.slash":"speaker.wave.2")};Spacer();Button("Replay"){play(applied ? "lab-complete":"intro-ai-lab")}.disabled(muted)}.font(.caption).padding(.horizontal,16).padding(.vertical,8)}
            if applied{ScrollView{VStack(alignment:.leading,spacing:18){Text("A clearer idea, still yours.").font(.title2.weight(.medium));Text(notes).font(.body).lineSpacing(5);Text("In your own editor, you can restore the original notes or choose Save. Nothing from this practice has been saved to your real work.").font(.subheadline).foregroundStyle(Design.muted);Button("Done — back to your guide"){narrator.stop();dismiss()}.buttonStyle(ActionStyle()).accessibilityIdentifier("ai-lab-done")}.padding(24)}}else{
                NativeRecordAssist(closeAfterApply:false,onToolSelected:{visited.insert($0.id);play("lab-tool-"+$0.id)},record:example){text,_ in notes=text;withAnimation(reducedMotion ? nil:.spring(duration:0.4,bounce:0.2)){applied=true};play("lab-complete")}.environmentObject(practice)
            }
        }.background(Design.background).toolbar(.hidden,for:.navigationBar)}.onAppear{play("intro-ai-lab")}.onDisappear{narrator.stop()}
    }
    func play(_ clip:String){guard narrationEnabled,!muted,let url=Bundle.main.url(forResource:clip,withExtension:"m4a",subdirectory:"GuideAudio/Aoede") else{return};narrator.playRecorded([url],voice:"Aoede")}

}
