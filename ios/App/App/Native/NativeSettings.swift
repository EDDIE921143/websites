import SwiftUI
import EdizCore

struct NativeSettings:View {
    @EnvironmentObject var store:NativeStore
    @State private var file:FilePreview?
    var body:some View {
        Form {
            Section("Your attention"){Picker("Current focus",selection:Binding(get:{store.preferences.focus},set:{store.setFocus($0)})){Text("Balanced").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}};Text("This gives the chosen space more weight. Deadlines still matter.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your data"){
                Button("Export full backup"){do{file=FilePreview(url:try store.export())}catch{store.error=error.localizedDescription}}
                if let last=Time.date(store.preferences.lastBackup){LabeledContent("Last shared backup",value:last.formatted(date:.abbreviated,time:.omitted))}
                NavigationLink("Import & restore"){NativeImport()}
                NavigationLink("History"){NativeHistory()}
                Text("Seven daily snapshots stay on this device. Export a backup to protect against device loss.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Local assistant"){
                Toggle("Enable local model connection",isOn:Binding(get:{store.preferences.labs},set:{store.configureModel(enabled:$0)}))
                if store.preferences.labs{
                    TextField("http://your-computer.local:1234/v1",text:Binding(get:{store.preferences.localEndpoint ?? ""},set:{store.configureModel(endpoint:$0)})).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Connect a model you run on your local network. Records are sent only when you switch on ‘Use my local model’ in Assistant and ask a question. No paid key is required.").font(.footnote).foregroundStyle(Design.muted)
                }
            }
            Section("Advanced"){NavigationLink("System health"){NativeHealth()};Text("Native edition 0.3.0 · No paid API required.").font(.footnote).foregroundStyle(Design.muted)}
        }.scrollContentBackground(.hidden).background(Design.background).navigationTitle("Settings")
            .sheet(item:$file){NativeShare(url:$0.url){completed in if completed{store.markBackupShared()}}}
    }
}
struct NativeShare:UIViewControllerRepresentable {
    let url:URL
    let completion:(Bool)->Void
    func makeUIViewController(context:Context)->UIActivityViewController{let controller=UIActivityViewController(activityItems:[url],applicationActivities:nil);controller.completionWithItemsHandler={_,completed,_,_ in Task{@MainActor in completion(completed)}};return controller}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
struct NativeHistory:View {
    @EnvironmentObject var store:NativeStore
    var months:[String]{Array(Set(store.activity.map{String($0.at.prefix(7))})).sorted(by:>)}
    var body:some View{List{if months.isEmpty{QuietEmpty(title:"Your history starts here.",message:"Saved work and decisions will be available to look back on.")};ForEach(months,id:\.self){month in Section(month){ForEach(store.activity.filter{$0.at.hasPrefix(month)}){event in VStack(alignment:.leading,spacing:5){Text(event.title).font(.body);Text("\(event.action) · \(Time.date(event.at)?.formatted(date:.abbreviated,time:.shortened) ?? event.at)").font(.caption).foregroundStyle(Design.muted)}}}}}.scrollContentBackground(.hidden).background(Design.background).navigationTitle("History")}
}
struct NativeHealth:View {
    @EnvironmentObject var store:NativeStore
    var body:some View { Form{Section("Local system"){LabeledContent("Database",value:"SQLite · WAL");LabeledContent("Records",value:String(store.records.count));LabeledContent("History",value:String(store.activity.count));LabeledContent("Storage",value:"App sandbox");LabeledContent("Offline",value:"Core always available");LabeledContent("Search",value:"Local lexical & fuzzy");LabeledContent("AI",value:"No model required");LabeledContent("Version",value:"0.3.0");Text("Data stays on this device. Speech requires on-device recognition. No telemetry is collected.").font(.footnote).foregroundStyle(Design.muted)}}.scrollContentBackground(.hidden).background(Design.background).navigationTitle("System health") }
}
