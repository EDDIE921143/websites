import SwiftUI
import UniformTypeIdentifiers
import EdizCore

struct NativeCapture:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft:Record
    @State private var automatic:Bool
    @State private var voicePrefix=""
    @State private var explicitDate=false
    @State private var date=Date()
    @StateObject private var speech=NativeSpeech()
    @FocusState private var typing:Bool
    init(seed:Record){_draft=State(initialValue:seed);_automatic=State(initialValue:seed.data["_captureAuto"] == "1");_date=State(initialValue:Time.date(seed.due) ?? Date());_explicitDate=State(initialValue:seed.due != nil)}
    var preview:Record {
        var parsed=CaptureParser.parse(draft.title)
        parsed.id=draft.id;parsed.created=draft.created
        if !automatic { parsed.space=draft.space;parsed.kind=draft.kind }
        parsed.status=Catalog.states(kind:parsed.kind,space:parsed.space)[0]
        if explicitDate { parsed.due=Time.string(date) }
        parsed.body=draft.body
        return parsed
    }
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What’s on your mind?",text:$draft.title,axis:.vertical).lineLimit(4...7).font(.body).focused($typing).accessibilityIdentifier("capture-text")
                    HStack{Spacer();Button{if !speech.listening{voicePrefix=draft.title};speech.toggle()}label:{Label(speech.listening ? "Stop listening":"Speak",systemImage:speech.listening ? "stop.circle":"mic")}.disabled(speech.requesting)}
                    if let error=speech.message { Text(error).font(.footnote).foregroundStyle(Design.muted) }
                }
                Section {
                    Toggle("Choose the space automatically",isOn:$automatic)
                    if !automatic { Picker("Space",selection:$draft.space){ForEach(Catalog.spaces){Text($0.name).tag($0.id)}};Picker("Type",selection:$draft.kind){ForEach(Catalog.space(draft.space).modules){Text($0.label).tag($0.kind)}} }
                    DisclosureGroup("Date") { Toggle("Set a date",isOn:$explicitDate);if explicitDate{DatePicker("When",selection:$date)} }
                }
                if !draft.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                    Section("Preview") { VStack(alignment:.leading,spacing:8){Text(preview.title).font(.body.weight(.medium));Text("\(Catalog.space(preview.space).name) · \(preview.kind)").font(.subheadline).foregroundStyle(Design.muted);if let due=Time.date(preview.due){Text(due,format:.dateTime.weekday().day().month().hour().minute()).font(.subheadline).foregroundStyle(Design.muted)};if preview.space == "moshia"{Text("POSSIBLE — canon only when you choose it.").font(.footnote).foregroundStyle(Design.muted)}} }
                }
            }.scrollContentBackground(.hidden).background(Design.background).navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){speech.stop();store.draft(draft);dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){speech.stop();if store.save(preview,action:"Created"){store.draft(nil);dismiss()}}.disabled(draft.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("capture-save")}}
                .onChange(of:draft){_,value in store.draft(value)}
                .onChange(of:draft.space){_,value in if !Catalog.space(value).modules.contains(where:{$0.kind == draft.kind}){draft.kind=Catalog.space(value).modules[0].kind}}
                .onChange(of:automatic){_,value in draft.data["_captureAuto"]=value ? "1":nil}
                .onChange(of:date){_,value in draft.due=explicitDate ? Time.string(value):nil}
                .onChange(of:explicitDate){_,value in draft.due=value ? Time.string(date):nil}
                .onChange(of:speech.transcript){_,value in if !value.isEmpty{draft.title=voicePrefix+(voicePrefix.isEmpty ? "":" ")+value} }
                .onDisappear{speech.stop()}
        }.tint(Design.accent).preferredColorScheme(.dark)
    }
}
struct NativeEditor:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    @State var record:Record
    @State private var deletion=false
    @State private var addingFile=false
    @State private var files:[Attachment]=[]
    @State private var preview:FilePreview?
    @State private var audio:FilePreview?
    @State private var hasDate=false
    @State private var date=Date()
    var body:some View {
        Form {
            Section {
                TextField("Title",text:$record.title,axis:.vertical).font(.body.weight(.medium)).accessibilityIdentifier("record-title")
                Picker("State",selection:$record.status){ForEach(Array(Set([record.status]+Catalog.states(kind:record.kind,space:record.space))).sorted(),id:\.self){Text($0).tag($0)}}
                Toggle("Scheduled",isOn:$hasDate)
                if hasDate{DatePicker("Date",selection:$date)}
            }
            if ["task","assignment","exam","lead"].contains(record.kind) {
                Section("Planning") {
                    Picker("Importance",selection:Binding(get:{record.importance ?? 2},set:{record.importance=$0})){Text("Low").tag(1);Text("Normal").tag(2);Text("Important").tag(4);Text("Essential").tag(5)}
                    TextField("Minutes needed",value:$record.duration,format:.number).keyboardType(.numberPad)
                    Toggle("Blocked",isOn:Binding(get:{record.blocked ?? false},set:{record.blocked=$0}))
                    Button("Start focus"){store.focusRequest=record}
                }
            }
            Section("Notes"){TextField("Context worth keeping",text:$record.body,axis:.vertical).lineLimit(4...15)}
            if !Catalog.fields(record.kind).isEmpty { Section("Details"){ForEach(Catalog.fields(record.kind),id:\.self){key in TextField(friendly(key),text:Binding(get:{record.data[key] ?? ""},set:{record.data[key]=$0}),axis:.vertical).lineLimit(1...7)}} }
            if let p=Priority.rank([record]).first { Section("Why Today may show this"){ForEach(p.reasons,id:\.self){Text($0).font(.subheadline).foregroundStyle(Design.muted)}} }
            Section("Files & recordings") {
                ForEach(files){file in Button{do{let url=try store.fileURL(file);if file.type.hasPrefix("audio/"){audio=FilePreview(url:url)}else{preview=FilePreview(url:url)}}catch{store.error=error.localizedDescription}}label:{Label(file.name,systemImage:file.type.hasPrefix("audio/") ? "waveform":"doc")}}
                Button("Attach a file"){addingFile=true}
            }
            Section { Button("Delete item",role:.destructive){deletion=true} }
        }.scrollContentBackground(.hidden).background(Design.background).navigationTitle(Catalog.space(record.space).name).navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.confirmationAction){Button("Save"){record.due=hasDate ? Time.string(date):nil;if store.save(record){dismiss()}}.disabled(record.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("record-save")}}
            .task{store.remember(record);do{if let draft=try store.database?.editDraft(recordID:record.id){record=draft};files=try store.database?.attachments(recordID:record.id) ?? []}catch{store.error=error.localizedDescription};hasDate=record.due != nil;date=Time.date(record.due) ?? Date()}
            .onChange(of:record){_,value in store.editDraft(value)}
            .onChange(of:date){_,value in record.due=hasDate ? Time.string(value):nil}
            .onChange(of:hasDate){_,value in record.due=value ? Time.string(date):nil}
            .confirmationDialog("Delete “\(record.title)”?",isPresented:$deletion,titleVisibility:.visible){Button("Delete item",role:.destructive){if store.remove(record){dismiss()}};Button("Keep it",role:.cancel){}}
            .fileImporter(isPresented:$addingFile,allowedContentTypes:[.item]){result in
                do{let url=try result.get();let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0;guard size<=32*1024*1024 else{store.error="Choose a file smaller than 32 MB.";return};let bytes=try Data(contentsOf:url);let type=UTType(filenameExtension:url.pathExtension)?.preferredMIMEType ?? "application/octet-stream";try store.database?.attach(Attachment(recordID:record.id,name:url.lastPathComponent,type:type,bytes:bytes));files=try store.database?.attachments(recordID:record.id) ?? []}catch{store.error="That file could not be saved. Your record is unchanged."}
            }.sheet(item:$preview){NativeFilePreview(url:$0.url)}.sheet(item:$audio){NativeAudioPractice(url:$0.url)}
    }
    func friendly(_ key:String)->String { key.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression).prefix(1).uppercased()+key.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression).dropFirst() }
}
struct NativeImport:View {
    @EnvironmentObject var store:NativeStore
    @State private var choose=false
    @State private var paste=""
    @State private var space="personal"
    @State private var items:[Record]=[]
    @State private var raw:Data?
    @State private var backup=false
    @State private var confirm=false
    @State private var message=""
    var body:some View {
        Form {
            Section("Destination"){Picker("Space",selection:$space){ForEach(Catalog.spaces){Text($0.name).tag($0.id)}}}
            Section("From a file"){Button("Choose CSV, JSON, Markdown or calendar"){choose=true};Text("Files are read locally. Existing records are kept unless you confirm a complete restore.").font(.footnote).foregroundStyle(Design.muted)}
            Section("From text"){TextField("Paste tasks, notes or lead information",text:$paste,axis:.vertical).lineLimit(4...8);Button("Review text"){items=paste.components(separatedBy:.newlines).filter{!$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty}.map{var r=CaptureParser.parse($0);r.space=space;r.status=Catalog.states(kind:r.kind,space:space)[0];return r};raw=nil;backup=false}.disabled(paste.isEmpty)}
            if !items.isEmpty {
                Section("Review · \(items.count) records"){ForEach(Array(items.prefix(30))){r in VStack(alignment:.leading,spacing:5){Text(r.title);Text("\(Catalog.space(r.space).name) · \(r.kind) · \(r.status)").font(.caption).foregroundStyle(Design.muted)}}}
                Section{Button("Import records"){if store.merge(items){message="Records imported. Title duplicates were skipped.";items=[]}};if backup{Text("Merge imports records only. Complete restore also includes files, history and preferences.").font(.footnote).foregroundStyle(Design.muted);Button("Restore this backup completely",role:.destructive){confirm=true}}}
            }
            if !message.isEmpty{Section{Text(message).font(.subheadline)}}
        }.scrollContentBackground(.hidden).background(Design.background).navigationTitle("Import")
            .fileImporter(isPresented:$choose,allowedContentTypes:[.json,.commaSeparatedText,.plainText,.text,UTType(filenameExtension:"ics") ?? .data]){result in
                do{let url=try result.get();let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0;guard size<=32*1024*1024 else{store.error="Choose a file smaller than 32 MB.";return};let data=try Data(contentsOf:url);items=try ImportParser.records(data:data,filename:url.lastPathComponent,space:space);raw=data;backup=(try? JSONDecoder().decode(Backup.self,from:data)) != nil;message=""}catch{store.error="That import could not be read. Your current records are unchanged."}
            }.confirmationDialog("Replace all current records, files, history and preferences?",isPresented:$confirm,titleVisibility:.visible){Button("Replace current data & restore",role:.destructive){if let raw,store.restore(raw){items=[];message="Backup restored."}};Button("Keep current data",role:.cancel){}}
    }
}
