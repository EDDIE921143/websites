import SwiftUI
import EdizCore
import PhotosUI
import Vision
import UserNotifications

enum MentorStyle {static let surface=Color(red:0.065,green:0.16,blue:0.15);static let inset=WorkspaceTheme.accent("tutoring").opacity(0.16)}

struct MentorSpaceCard:View {
    @EnvironmentObject var store:NativeStore
    var body:some View {
        VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 10:22){
            NavigationLink{NativeMentorDesk()}label:{HStack(spacing:12){SpaceMark(space:Catalog.spaces.first{$0.id == "tutoring"}!);VStack(alignment:.leading,spacing:4){Text("Mentor Desk").font(Design.font(19,weight:"DemiBold"));if store.preferences.density != "compact"{Text("\(MentorDesk.students(in:store.records).count) students · Shared learning").font(Design.font(13,weight:"Regular")).foregroundStyle(Design.muted)}};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(Design.muted)}}.buttonStyle(.plain).accessibilityIdentifier("space-tutoring").walkthroughTarget("mentor-space",session:store.walkthrough)
            HStack(spacing:8){GlassAction{NavigationLink{NativeMentorDesk()}label:{Label("Students",systemImage:"person.2").font(Design.font(13)).frame(maxWidth:.infinity,minHeight:44)}};GlassAction{NavigationLink{NativeMentorDesk(initialMode:"Calendar")}label:{Label("Calendar",systemImage:"calendar").font(Design.font(13)).frame(maxWidth:.infinity,minHeight:44)}}}
        }.padding(store.preferences.density == "compact" ? 12:24).background{WorkspacePanel(scope:"tutoring").clipShape(RoundedRectangle(cornerRadius:24))}.overlay{RoundedRectangle(cornerRadius:24).strokeBorder(WorkspaceTheme.accent("tutoring").opacity(0.18),lineWidth:1)}
    }
}
struct NativeMentorDesk:View {
    @EnvironmentObject var store:NativeStore
    @State private var adding=false
    @State private var selectedDate=Date()
    var initialMode="Students"
    @State private var mode="Students"
    @State private var search=""
    @State private var showArchived=false
    @State private var remindersMessage:String?
    var students:[EdizCore.Record]{(showArchived ? store.records.filter{$0.space == "tutoring" && $0.data["mentorType"] == "student" && $0.status == "archived"}:MentorDesk.students(in:store.records)).filter{search.isEmpty || ($0.title+($0.data["subjects"] ?? "")).localizedCaseInsensitiveContains(search)}}
    var agenda:[EdizCore.Record]{store.records.filter{$0.space == "tutoring" && $0.status != "archived" && $0.status != "done" && Time.date($0.due).map{Calendar.current.isDate($0,inSameDayAs:selectedDate)} == true}.sorted{($0.due ?? "")<($1.due ?? "")}}
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            HStack(alignment:.top){VStack(alignment:.leading,spacing:6){Text("LEARNING, TOGETHER").font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(WorkspaceTheme.accent("tutoring"));Text("Small steps. Real progress.").font(Design.font(27,weight:"DemiBold"));Text("Keep each student’s next step close.").font(.subheadline).foregroundStyle(Design.muted)};Spacer();Text("\(students.count)").font(.system(size:42,weight:.light,design:.rounded)).monospacedDigit().foregroundStyle(WorkspaceTheme.accent("tutoring"))}.padding(.top,8)
            MentorWeekStrip(selected:$selectedDate,records:store.records){mode="Calendar"}
            HStack(spacing:12){Button{adding=true}label:{Label("Add student",systemImage:"plus").frame(maxWidth:.infinity)}.buttonStyle(ActionStyle()).accessibilityIdentifier("mentor-add-student").walkthroughTarget("mentor-add-student",session:store.walkthrough);Menu{NavigationLink("Mentor Desk guide"){NativeTutorial()};Button(showArchived ? "Show active students":"Show archived students"){showArchived.toggle()};Button("Focus on Mentor Desk"){var p=store.preferences;p.focus="tutoring";store.setPreferences(p)};Button("Disable Mentor reminders"){Task{await MentorNotifications.disable();remindersMessage="Mentor reminders are off."}};Button("Enable session reminders"){Task{let ok=await MentorNotifications.enable(records:store.records);remindersMessage=ok ? "Reminders are on for your students’ sessions and tests.":"Notifications are not allowed. Enable them in iPhone Settings."}}}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.disabled(store.isPractice).accessibilityLabel("Mentor Desk options")}
            if let remindersMessage{Text(remindersMessage).font(.caption).foregroundStyle(Design.muted)}
            Picker("View",selection:$mode){Text("Students").tag("Students");Text("Calendar").tag("Calendar")}.pickerStyle(.segmented).onChange(of:mode){_,value in if value == "Calendar"{store.walkthrough?.event("mentor-calendar")}}.walkthroughTarget("mentor-calendar",session:store.walkthrough)
            if mode == "Students"{
                TextField("Find a student or subject",text:$search).padding(14).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("mentor-search")
                Text(showArchived ? "Archived students":"Student directory").font(.headline)
                if students.isEmpty{ContentUnavailableView("Room for your first student",systemImage:"person.crop.circle.badge.plus",description:Text("Add their name and subjects. You can capture a session straight away."))}
                ForEach(students){student in NavigationLink{MentorStudentPage(studentID:student.id)}label:{MentorStudentRow(student:student)}.buttonStyle(.plain).accessibilityIdentifier("mentor-student-"+student.id)}
            }else{
                DatePicker("Choose a day",selection:$selectedDate,displayedComponents:.date).datePickerStyle(.graphical).tint(WorkspaceTheme.accent("tutoring"))
                Text(selectedDate.formatted(date:.complete,time:.omitted)).font(.headline)
                if agenda.isEmpty{Text("No sessions or tests on this day.").foregroundStyle(Design.muted).padding(.vertical,12)}
                ForEach(agenda){item in if let studentID=item.data["studentID"]{NavigationLink{MentorStudentPage(studentID:studentID)}label:{MentorItemRow(item:item)}.buttonStyle(.plain)}}
            }
        }.padding(20).padding(.bottom,24)}.background(AppBackdrop(scope:"tutoring")).navigationTitle("Mentor Desk").navigationBarTitleDisplayMode(.inline).tint(WorkspaceTheme.accent("tutoring"))
        .sheet(isPresented:$adding){MentorStudentEditor(onClose:{adding=false})}.onAppear{mode=initialMode;store.walkthrough?.event("mentor-open");if !store.isPractice && UserDefaults.standard.bool(forKey:"mentor-reminders-enabled"){Task{await MentorNotifications.refresh(records:store.records)}}}
    }
}
struct MentorWeekStrip:View {
    @Binding var selected:Date
    let records:[EdizCore.Record]
    var choose:()->Void
    var days:[Date]{let calendar=Calendar.current;let today=calendar.startOfDay(for:Date());let monday=calendar.date(byAdding:.day,value:-((calendar.component(.weekday,from:today)+5)%7),to:today)!;return (0..<7).compactMap{calendar.date(byAdding:.day,value:$0,to:monday)}}
    var body:some View{HStack(spacing:5){ForEach(days,id:\.self){day in let active=Calendar.current.isDate(day,inSameDayAs:selected);let count=records.filter{$0.space == "tutoring" && $0.status != "done" && Time.date($0.due).map{Calendar.current.isDate($0,inSameDayAs:day)} == true}.count;Button{selected=day;choose()}label:{VStack(spacing:9){Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2);Text(day.formatted(.dateTime.day())).font(.headline).monospacedDigit();Circle().fill(count>0 ? WorkspaceTheme.accent("tutoring"):.clear).frame(width:4,height:4)}.frame(maxWidth:.infinity).padding(.vertical,13).foregroundStyle(active ? Color.black:Design.ink).background(active ? WorkspaceTheme.accent("tutoring"):MentorStyle.surface,in:RoundedRectangle(cornerRadius:13))}.buttonStyle(.plain).accessibilityLabel(day.formatted(date:.complete,time:.omitted)+", \(count) items")}}}
}
struct MentorStudentRow:View {
    let student:EdizCore.Record
    var showArrow=true
    var body:some View{HStack(spacing:16){
        ZStack(alignment:.bottomTrailing){RoundedRectangle(cornerRadius:12).fill(MentorStyle.inset).frame(width:48,height:54);Text(String(student.title.prefix(1))).font(.title2.weight(.medium)).frame(width:48,height:54);}
        VStack(alignment:.leading,spacing:5){Text(student.title).font(.headline);Text(student.data["subjects"]?.isEmpty == false ? student.data["subjects"]!:"No subjects yet").font(.subheadline).foregroundStyle(Design.muted);if let year=student.data["year"],!year.isEmpty{Text("CLASS "+year).font(.caption2.weight(.medium)).tracking(1).foregroundStyle(WorkspaceTheme.accent("tutoring"))}}
        Spacer(minLength:8);if showArrow{Image(systemName:"chevron.right").font(.subheadline).foregroundStyle(WorkspaceTheme.accent("tutoring"))}
    }.padding(.vertical,17).padding(.horizontal,16).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:16))}
}
struct MentorStudentEditor:View {
    func close(){if let onClose{onClose()}else{dismiss()}}
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    var existing:EdizCore.Record?=nil
    var onClose:(()->Void)?=nil
    @State private var first=""
    @State private var last=""
    @State private var subjects=""
    @State private var year=""
    var body:some View{NavigationStack{Form{Section("Student"){TextField("First name",text:$first).accessibilityIdentifier("mentor-first-name");TextField("Last name",text:$last).accessibilityIdentifier("mentor-last-name");TextField("Year / class (optional)",text:$year)};Section("Subjects you tutor"){TextField("e.g. Maths, English",text:$subjects).accessibilityIdentifier("mentor-subjects");Text("Their own learning area, separate from your School space.").font(.caption).foregroundStyle(Design.muted)}}.safeAreaInset(edge:.top){if let session=store.walkthrough{WalkthroughCoach(session:session)}}.navigationTitle(existing == nil ? "New student":"Edit student").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){close()}};ToolbarItem(placement:.confirmationAction){Button("Save"){var record=MentorDesk.student(first:first,last:last,subjects:subjects,year:year);if let existing{record.id=existing.id;record.created=existing.created;record.body=existing.body;record.status=existing.status};if store.save(record,action:existing == nil ? "Created":"Updated"){store.walkthrough?.event("mentor-student-saved");close()}}.disabled(first.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("mentor-save-student")}}.onAppear{first=existing?.data["firstName"] ?? "";last=existing?.data["lastName"] ?? "";subjects=existing?.data["subjects"] ?? "";year=existing?.data["year"] ?? ""}}}
}
struct MentorStudentPage:View {
    @EnvironmentObject var store:NativeStore
    let studentID:String
    @State private var archiving=false
    @State private var edit=false
    @State private var composing:String?
    @State private var selected:EdizCore.Record?
    @State private var deleting:EdizCore.Record?
    var student:EdizCore.Record?{store.records.first{$0.id==studentID && $0.space == "tutoring"}}
    var items:[EdizCore.Record]{MentorDesk.context(for:studentID,in:store.records).filter{$0.id != studentID && $0.status != "archived"}.sorted{$0.created>$1.created}}
    var body:some View{Group{if let student{ScrollView{VStack(alignment:.leading,spacing:22){
        MentorStudentRow(student:student,showArrow:false)
        HStack(spacing:10){Button{composing="session"}label:{Label("Log session",systemImage:"square.and.pencil").frame(maxWidth:.infinity)}.buttonStyle(ActionStyle()).accessibilityIdentifier("mentor-log-session").walkthroughTarget("mentor-log-session",session:store.walkthrough);NavigationLink{MentorStudentChat(studentID:studentID)}label:{Image(systemName:"sparkles").frame(width:46,height:46).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:15))}.accessibilityLabel("Student assistant").accessibilityIdentifier("mentor-student-assistant")}
        HStack(spacing:10){Button("Session date"){composing="appointment"};Button("Their test"){composing="exam"}.walkthroughTarget("mentor-test",session:store.walkthrough);Button("Learning goal"){composing="goal"}}.font(.subheadline).buttonStyle(.bordered).controlSize(.regular)
        let scheduled=items.filter{$0.status != "done" && Time.date($0.due).map{$0>=Date()} == true}.sorted{($0.due ?? "")<($1.due ?? "")}
        if !scheduled.isEmpty{Text("Coming up for "+(student.data["firstName"] ?? student.title)).font(.title3.weight(.semibold));ForEach(scheduled){item in itemButton(item)}}
        Text("Learning journal").font(.title3.weight(.semibold))
        if items.isEmpty{Text("After your first session, record what you covered and what comes next. Type, speak in German or English, or add a photo.").foregroundStyle(Design.muted)}
        ForEach(items.filter{$0.due == nil || $0.status == "done" || Time.date($0.due).map{$0<Date()} == true}){item in itemButton(item)}
    }.padding(20).padding(.bottom,24)}.navigationTitle(student.data["firstName"] ?? student.title).toolbar{ToolbarItem(placement:.topBarTrailing){Menu{Button("Edit student"){edit=true};Button(student.status == "archived" ? "Restore student":"Archive student"){archiving=true}}label:{Image(systemName:"ellipsis")}.accessibilityLabel("Student options")}}.sheet(isPresented:$edit){MentorStudentEditor(existing:student,onClose:{edit=false})}.sheet(isPresented:Binding(get:{composing != nil},set:{if !$0{composing=nil}})){MentorItemEditor(student:student,type:composing ?? "session",onClose:{composing=nil})}.sheet(item:$selected){MentorItemEditor(student:student,type:$0.data["mentorType"] ?? "session",existing:$0,onClose:{selected=nil})}
    }else{ContentUnavailableView("Student unavailable",systemImage:"person.crop.circle.badge.exclamationmark")}}.background(AppBackdrop(scope:"tutoring")).tint(WorkspaceTheme.accent("tutoring")).confirmationDialog("Change student availability?",isPresented:$archiving){Button(student?.status == "archived" ? "Restore student":"Archive student"){if var student{student.status=student.status == "archived" ? "active":"archived";_ = store.save(student)}}}message:{Text("Session notes and learning history are kept. Archived students receive no new Mentor reminders.")}.confirmationDialog("Delete this entry?",isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}})){Button("Delete entry",role:.destructive){if let deleting{_ = store.remove(deleting)};deleting=nil}}
    }
    func itemButton(_ item:EdizCore.Record)->some View{Button{selected=item}label:{MentorItemRow(item:item)}.buttonStyle(.plain).contextMenu{if item.status != "done"{Button("Mark complete"){store.complete(item)}};Button("Edit"){selected=item};Button("Delete",role:.destructive){deleting=item}}}
}
struct MentorItemRow:View {
    let item:EdizCore.Record
    var body:some View{VStack(alignment:.leading,spacing:9){HStack{Label(item.data["mentorType"] == "exam" ? "Their test":item.data["mentorType"] == "appointment" ? "Tutoring session":item.data["mentorType"] == "goal" ? "Learning goal":"Session note",systemImage:item.kind == "exam" ? "doc.text":"pencil.and.list.clipboard").font(.caption.weight(.semibold)).foregroundStyle(WorkspaceTheme.accent("tutoring"));Spacer();if item.status == "done"{Image(systemName:"checkmark.circle.fill")}};Text(item.title).font(.headline);Text([item.data["studentName"],item.data["subject"]].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).foregroundStyle(Design.muted);if let date=Time.date(item.due){Text(date.formatted(date:.abbreviated,time:.shortened)).font(.subheadline)};if !item.body.isEmpty{Text(item.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(3)}}.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:20))}
}
struct MentorItemEditor:View {
    func close(){if let onClose{onClose()}else{dismiss()}}
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    let student:EdizCore.Record
    let type:String
    var existing:EdizCore.Record?=nil
    var onClose:(()->Void)?=nil
    @State private var title=""
    @State private var subject=""
    @State private var bodyText=""
    @State private var date=Date().addingTimeInterval(3600)
    @State private var reminder="30"
    @State private var photo:PhotosPickerItem?
    @State private var photoFile:AssistantAttachment?
    @State private var photoInfo:AssistantAttachmentInfo?
    @State private var image:UIImage?
    @State private var camera=false
    @State private var busy=false
    @State private var finishing=false
    @State private var aiSources:[AssistantSource]=[]
    @State private var aiDraft:String?
    @State private var clarification=""
    @State private var originalText:String?
    @State private var message:String?
    @State private var language="de-DE"
    @State private var job:Task<Void,Never>?
    @StateObject private var speech=NativeSpeech()
    var hasDate:Bool{type == "appointment" || type == "exam" || type == "goal"}
    var body:some View{NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){
        Text(student.title).font(.title2.weight(.semibold));Text(type == "session" ? "What did you work on together?":"Keep their next step in view.").foregroundStyle(Design.muted)
        TextField(type == "session" ? "Topic (optional for a quick note)":"Title",text:$title).textFieldStyle(.roundedBorder).accessibilityIdentifier("mentor-item-title")
        TextField("Subject",text:$subject).textFieldStyle(.roundedBorder)
        if hasDate{DatePicker(type == "exam" ? "Their test date":"When",selection:$date);Picker("Remind me",selection:$reminder){Text("At the time").tag("0");Text("30 minutes before").tag("30");Text("1 hour before").tag("60");Text("1 day before").tag("1440")}}
        if speech.listening{HStack{Image(systemName:"mic.fill").foregroundStyle(WorkspaceTheme.accent("tutoring"));Text("Listening to your session note…");Spacer();Button{finishSpeech()}label:{Image(systemName:"stop.fill").frame(width:44,height:44)}.accessibilityLabel("Stop recording")};ProgressView(value:Double(speech.level),total:1).tint(WorkspaceTheme.accent("tutoring"))}else{
            TextEditor(text:$bodyText).frame(minHeight:170).padding(8).scrollContentBackground(.hidden).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("mentor-item-body")
            HStack{Picker("Speech language",selection:$language){Text("German").tag("de-DE");Text("English").tag("en-US")}.pickerStyle(.menu);Spacer();Button{speech.localeIdentifier=language;speech.toggle()}label:{Label("Speak",systemImage:"mic.fill")}.disabled(busy || finishing || speech.requesting)}
        }
        if finishing{ProgressView("Finishing your recording…")}
        if let warning=speech.message{Text(warning).font(.caption).foregroundStyle(Design.muted)}
        HStack{PhotosPicker(selection:$photo,matching:.images){Label("Add photo",systemImage:"photo")};Spacer();Button{camera=true}label:{Label("Camera",systemImage:"camera")}}
        if let image{Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:220).clipShape(RoundedRectangle(cornerRadius:16));Button("Remove photo",role:.destructive){self.image=nil;photoFile=nil;photoInfo=nil}}
        Button{polish()}label:{Label(type == "session" ? "Clarify topic & polish note":"Help plan the next step",systemImage:"sparkles").frame(maxWidth:.infinity)}.buttonStyle(.bordered).disabled(busy || speech.listening || finishing || (bodyText.isEmpty && photoFile == nil)).accessibilityIdentifier("mentor-polish")
        Text("AI uses only this student’s saved context and the material you choose here. Review any corrected topic before saving.").font(.caption).foregroundStyle(Design.muted)
        if busy{ProgressView("Checking the topic and preparing a suggestion…")}
        Button("Verify the topic online"){polish(verify:true)}.disabled(busy || title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || speech.listening || finishing)
        if let aiDraft{VStack(alignment:.leading,spacing:14){Text("Review suggestion").font(.headline);NativeRichText(text:aiDraft);ForEach(aiSources,id:\.url){source in if let url=URL(string:source.url){Link(source.title,destination:url).font(.caption)}};Button("Use this note"){if originalText == nil{originalText=bodyText};bodyText=aiDraft;self.aiDraft=nil}.buttonStyle(ActionStyle());TextField("Answer a clarification or refine the suggestion",text:$clarification).textFieldStyle(.roundedBorder);Button("Ask a follow-up"){polish()}.disabled(clarification.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || busy);Button("Keep my original"){self.aiDraft=nil}}.padding(18).background(MentorStyle.surface,in:RoundedRectangle(cornerRadius:18))}
        if let message{Text(message).font(.subheadline).foregroundStyle(Design.muted)}
    }.padding(20)}.background(AppBackdrop(scope:"tutoring")).safeAreaInset(edge:.top){if let session=store.walkthrough{WalkthroughCoach(session:session)}}.navigationTitle(type == "session" ? "Session note":type == "exam" ? "Their test":type == "goal" ? "Learning goal":"Tutoring session").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){close()}};ToolbarItem(placement:.confirmationAction){Button("Save"){save()}.disabled((title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (type != "session" || bodyText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)) || speech.listening || finishing || busy).accessibilityIdentifier("mentor-save-item")}}
     .onAppear{store.walkthrough?.event(type == "session" ? "mentor-session-open":"mentor-test-open");title=existing?.title ?? "";subject=existing?.data["subject"] ?? student.data["subjects"]?.components(separatedBy:",").first ?? "";bodyText=existing?.body ?? "";date=Time.date(existing?.due) ?? date;reminder=existing?.data["reminderMinutes"] ?? (type == "exam" ? "1440":"30");if let text=existing?.data["material"],let data=text.data(using:.utf8),let info=try? JSONDecoder().decode(AssistantAttachmentInfo.self,from:data),let url=try? store.memoURL(info),let bytes=try? Data(contentsOf:url){photoInfo=info;image=UIImage(data:bytes);photoFile=AssistantAttachment(name:info.name,mimeType:info.mimeType,bytes:bytes)}}
    .onChange(of:photo){_,value in guard let value else{return};job?.cancel();job=Task{@MainActor in do{if let data=try await value.loadTransferable(type:Data.self),let image=UIImage(data:data){await preparePhoto(image)}}catch{message="The photo couldn’t be opened. Try another image."}}}
    .sheet(isPresented:$camera){MentorCamera{image in camera=false;if let image{job=Task{@MainActor in await preparePhoto(image)}}}}
    .onDisappear{job?.cancel();speech.stop()}}}
    func finishSpeech(){finishing=true;job=Task{@MainActor in let text=await speech.finish();guard !Task.isCancelled else{return};if !text.isEmpty{bodyText+=(bodyText.isEmpty ? "":"\n\n")+text};finishing=false}}
    func preparePhoto(_ image:UIImage) async {
        let scale=min(1,1600/max(image.size.width,image.size.height));let size=CGSize(width:image.size.width*scale,height:image.size.height*scale)
        let resized=UIGraphicsImageRenderer(size:size).image{_ in image.draw(in:CGRect(origin:.zero,size:size))}
        guard let bytes=resized.jpegData(compressionQuality:0.75),bytes.count<AssistantMedia.limit else{message="This photo is too large. Try a smaller image.";return};guard !Task.isCancelled else{return}
        self.image=resized;photoInfo=nil;photoFile=AssistantAttachment(name:"Learning material.jpg",mimeType:"image/jpeg",bytes:bytes)
        do{let text=try await Task.detached{let request=VNRecognizeTextRequest();request.recognitionLevel = .accurate;request.recognitionLanguages=["de-DE","en-US"];request.usesLanguageCorrection=true;try VNImageRequestHandler(data:bytes).perform([request]);return (request.results ?? []).compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n")}.value;guard !Task.isCancelled else{return};if !text.isEmpty{bodyText+=(bodyText.isEmpty ? "":"\n\n")+"Photo text (check accuracy):\n"+text};message=text.isEmpty ? "Photo added. The bot can help inspect it when you ask.":"Photo text extracted on this device. Check the wording before saving."}catch{message="Photo added. Text recognition couldn’t read it clearly."}
    }
    func polish(verify:Bool=false){guard let token=store.assistantToken else{message="Connect your assistant in Settings. Your note can still be saved.";return};busy=true;message=nil;job=Task{@MainActor in defer{busy=false};do{let prompt=(verify ? "Search online for the correct standard term for this learning topic, cite sources, and flag ambiguity. ":"")+"Ediz is this student's peer tutor. Review this session note in its original German or English. Identify likely topic names carefully, remove spoken filler, and structure: what we covered, what needs practice, next step. Do not invent facts or dates. If unclear, ask one clarification instead of guessing. Return only a reviewable note, no saved actions. Subject: \(subject). Topic: \(title). Note: \(bodyText). Previous suggestion or question: \(aiDraft ?? ""). Tutor clarification: \(clarification)";let reply=try await GeminiAssistant.answer(question:String(prompt.prefix(7900)),records:MentorDesk.context(for:student.id,in:store.records),conversation:[],token:token,scope:"tutoring",attachments:photoFile.map{[$0]} ?? [],studentID:student.id);guard !Task.isCancelled else{return};aiDraft=reply.text;aiSources=reply.sources ?? [];clarification=""}catch{if !Task.isCancelled{message=error.localizedDescription}}}}
    func save(){let savedTitle=title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? String(bodyText.trimmingCharacters(in:.whitespacesAndNewlines).prefix(70)):title;var r=MentorDesk.item(student:student,type:type,title:savedTitle,subject:subject,body:bodyText,due:hasDate ? date:nil);if let existing{r.id=existing.id;r.created=existing.created;r.status=existing.status;r.data.merge(existing.data){new,_ in new}};r.data["reminderMinutes"]=reminder;if let originalText{r.data["originalNote"]=String(originalText.prefix(4000))};do{if let photoFile{let info=try photoInfo ?? store.keepMemo(photoFile);r.data["material"]=String(decoding:try JSONEncoder().encode(info),as:UTF8.self)}else{r.data.removeValue(forKey:"material")};if store.save(r,action:existing == nil ? "Created":"Updated"){store.walkthrough?.event(type == "session" ? "mentor-session-saved":"mentor-test-saved");close()}}catch{message="Your photo couldn’t be saved. Please try again."}}
}
struct MentorStudentChat:View {
    @EnvironmentObject var store:NativeStore
    let studentID:String
    @State private var threadID:UUID?
    @State private var question=""
    var historyScope:String{"tutoring:"+studentID}
    var thread:ChatThread?{store.chatShelf(historyScope).threads.first{$0.id==threadID}}
    var body:some View{Group{if let threadID{NativeAssistantChat(entries:Binding(get:{thread?.entries ?? []},set:{store.saveThread($0,id:threadID,scope:historyScope)}),question:$question,scope:"tutoring",studentID:studentID,historyScope:historyScope,threadID:threadID,selectThread:{id in store.selectThread(id,scope:historyScope);self.threadID=id;question=""}).id(threadID)}else{ProgressView()}}.onAppear{if threadID == nil{threadID=store.openThread(scope:historyScope)}}.onChange(of:thread?.entries.count){_,_ in if let threadID,let thread,!thread.titled,let first=thread.entries.first(where:{$0.role == "user" && $0.text.split(separator:" ").count>4}){store.nameThread(threadID,scope:historyScope,title:String(first.text.prefix(70)))}}}
}
struct MentorCamera:UIViewControllerRepresentable {
    var finished:(UIImage?)->Void
    func makeCoordinator()->Coordinator{Coordinator(finished:finished)}
    func makeUIViewController(context:Context)->UIImagePickerController{let picker=UIImagePickerController();picker.sourceType=UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera:.photoLibrary;picker.delegate=context.coordinator;return picker}
    func updateUIViewController(_ uiViewController:UIImagePickerController,context:Context){}
    final class Coordinator:NSObject,UIImagePickerControllerDelegate,UINavigationControllerDelegate{let finished:(UIImage?)->Void;init(finished:@escaping(UIImage?)->Void){self.finished=finished};func imagePickerControllerDidCancel(_ picker:UIImagePickerController){finished(nil)};func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]){finished(info[.originalImage] as? UIImage)}}
}
@MainActor enum MentorNotifications {
    static let prefix="edizos-mentor-"
    static func enable(records:[EdizCore.Record]) async -> Bool{let granted=(try? await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound])) ?? false;guard granted else{return false};UserDefaults.standard.set(true,forKey:"mentor-reminders-enabled");await refresh(records:records);return true}
    static func disable() async{UserDefaults.standard.set(false,forKey:"mentor-reminders-enabled");let center=UNUserNotificationCenter.current();center.removePendingNotificationRequests(withIdentifiers:await center.pendingNotificationRequests().map(\.identifier).filter{$0.hasPrefix(prefix)})}
    static func refresh(records:[EdizCore.Record]) async {
        guard UserDefaults.standard.bool(forKey:"mentor-reminders-enabled") else{return}
        let center=UNUserNotificationCenter.current();let pending=await center.pendingNotificationRequests();center.removePendingNotificationRequests(withIdentifiers:pending.map(\.identifier).filter{$0.hasPrefix(prefix)})
        let activeStudents=Set(MentorDesk.students(in:records).map(\.id))
        let items=records.filter{activeStudents.contains($0.data["studentID"] ?? "")}.compactMap{r -> (EdizCore.Record,Date)? in guard let date=MentorDesk.reminderDate(r) else{return nil};return(r,date)}.sorted{$0.1<$1.1}.prefix(max(0,60-pending.filter{!$0.identifier.hasPrefix(prefix)}.count))
        for (r,date) in items{let content=UNMutableNotificationContent();content.title=r.data["mentorType"] == "exam" ? "Their test is coming up":"Tutoring session coming up";content.body=(r.data["studentName"] ?? "Student")+" · "+r.title;content.sound = .default;NativeReminderScheduler.identify(content,space:"tutoring");let trigger=UNCalendarNotificationTrigger(dateMatching:Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:date),repeats:false);do{try await center.add(UNNotificationRequest(identifier:prefix+r.id,content:content,trigger:trigger))}catch{}}
    }
}
