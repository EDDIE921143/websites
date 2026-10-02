import SwiftUI
import EdizCore

struct NativeSettings:View {
    @EnvironmentObject var store:NativeStore
    @State private var file:FilePreview?
    @State private var testing=false
    @State private var modelStatus="Not tested. No records are sent by a connection test."
    @State private var checkedEndpoint=""
    var body:some View {
        Form {
            Section("Look & feel"){Picker("Density",selection:Binding(get:{store.preferences.density},set:{var next=store.preferences;next.density=$0;store.setPreferences(next)})){Text("Comfortable").tag("comfortable");Text("Compact").tag("compact")}.pickerStyle(.segmented);Text("Changes spacing while keeping touch targets comfortable.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your attention"){Picker("Current focus",selection:Binding(get:{store.preferences.focus},set:{store.setFocus($0)})){Text("Balanced").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}};Text("This gives the chosen space more weight. Deadlines still matter.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your data"){
                Button("Export full backup"){do{file=FilePreview(url:try store.export())}catch{store.error=error.localizedDescription}}
                Button("Export Ediz OS profile"){do{file=FilePreview(url:try store.exportProfile())}catch{store.error=error.localizedDescription}}
                if let last=Time.date(store.preferences.lastBackup){LabeledContent("Last shared backup",value:last.formatted(date:.abbreviated,time:.omitted))}
                NavigationLink("Import & restore"){NativeImport()}
                NavigationLink("History"){NativeHistory()}
                Text("Seven daily snapshots stay on this device. Export a backup to protect against device loss.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Assistant context"){
                LabeledContent("Cloud assistant",value:store.assistantConnected ? "Connected":"Not connected")
                NavigationLink("Review saved context"){NativeAssistantContext()}
                Text("Your workspace briefs and chapter summaries are available to the assistant. You can read and edit them here.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Local assistant"){
                Toggle("Enable local model connection",isOn:Binding(get:{store.preferences.labs},set:{store.configureModel(enabled:$0)}))
                if store.preferences.labs{
                    TextField("http://your-computer.local:1234/v1",text:Binding(get:{store.preferences.localEndpoint ?? ""},set:{store.configureModel(endpoint:$0)})).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(testing ? "Testing connection…":"Test connection") {
                        let endpoint=store.preferences.localEndpoint ?? ""
                        testing=true;checkedEndpoint=endpoint;modelStatus="Testing…"
                        Task { @MainActor in
                            defer{testing=false}
                            do {let names=try await LocalAssistant.models(endpoint:endpoint);if store.preferences.localEndpoint == endpoint{modelStatus="Connected · "+names.joined(separator:", ")}}
                            catch {if store.preferences.localEndpoint == endpoint{modelStatus="Not available. Check that a model is loaded, the LAN address is correct, and local-network access is allowed."}}
                        }
                    }.disabled(testing)
                    Text(checkedEndpoint == (store.preferences.localEndpoint ?? "") ? modelStatus:"Not tested for this address.").font(.footnote).foregroundStyle(Design.muted).accessibilityIdentifier("local-model-status")
                    Text("On iPhone, localhost means this phone. For a model on your Mac, use the Mac’s LAN address on the same Wi-Fi.").font(.footnote).foregroundStyle(Design.muted)
                    Text("Connect a model you run on your local network. Records are sent only when you switch on ‘Use my local model’ in Assistant and ask a question. No paid key is required.").font(.footnote).foregroundStyle(Design.muted)
                }
            }
            Section("Advanced"){NavigationLink("System health"){NativeHealth()};Text("Native edition 0.3.9 · No paid API required.").font(.footnote).foregroundStyle(Design.muted)}
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Settings")
            .sheet(item:$file){shared in NativeShare(url:shared.url){completed in if completed && shared.url.lastPathComponent.hasPrefix("ediz-os-"){store.markBackupShared()}}}
    }
}
struct NativeShare:UIViewControllerRepresentable {
    let url:URL
    let completion:(Bool)->Void
    func makeUIViewController(context:Context)->UIActivityViewController{let controller=UIActivityViewController(activityItems:[url],applicationActivities:nil);controller.completionWithItemsHandler={_,completed,_,_ in Task{@MainActor in completion(completed)}};return controller}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
struct NativeAssistantContext:View {
    @EnvironmentObject var store:NativeStore
    @State private var syncing=false
    var body:some View {
        List {
            Section {
                Text("Saved context belongs to you. Each chat uses its workspace records; Everyday can use every space.").font(.subheadline).foregroundStyle(Design.muted)
                Button(syncing ? "Refreshing…":"Refresh context") {
                    syncing=true
                    Task{@MainActor in await store.refresh();syncing=false}
                }.disabled(syncing).accessibilityIdentifier("refresh-assistant-context")
            }
            ForEach(Catalog.spaces) { space in
                Section(space.name) {
                    let briefs=store.records.filter{$0.space == space.id && $0.data["contextType"] == "workspace-brief"}
                    ForEach(briefs) { brief in
                        NavigationLink(value:brief) {
                            VStack(alignment:.leading,spacing:8) {
                                Text(brief.title).foregroundStyle(Design.ink)
                                Text(brief.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(4)
                                if let sources=brief.data["source"] {Text(sources).font(.caption).foregroundStyle(Design.color(space.color))}
                            }.padding(.vertical,6)
                        }
                    }
                    if briefs.isEmpty{Text("No workspace brief saved yet.").foregroundStyle(Design.muted)}
                    if space.id == "moshia" {
                        NavigationLink(value:SpaceRoute(id:"moshia",kind:"chapter")) {
                            LabeledContent("Chapter summaries",value:String(store.records.filter{$0.space == "moshia" && $0.kind == "chapter"}.count))
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Assistant context")
    }
}
struct NativeHistory:View {
    @EnvironmentObject var store:NativeStore
    var months:[String]{Array(Set(store.activity.map{String($0.at.prefix(7))})).sorted(by:>)}
    var body:some View{List{if months.isEmpty{QuietEmpty(title:"Your history starts here.",message:"Saved work and decisions will be available to look back on.")};ForEach(months,id:\.self){month in Section(month){ForEach(store.activity.filter{$0.at.hasPrefix(month)}){event in VStack(alignment:.leading,spacing:5){Text(event.title).font(.body);Text("\(event.action) · \(Time.date(event.at)?.formatted(date:.abbreviated,time:.shortened) ?? event.at)").font(.caption).foregroundStyle(Design.muted)}}}}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("History")}
}
struct NativeHealth:View {
    @EnvironmentObject var store:NativeStore
    var body:some View { Form{Section("Local system"){LabeledContent("Database",value:"SQLite · WAL");LabeledContent("Records",value:String(store.records.count));LabeledContent("History",value:String(store.activity.count));LabeledContent("Storage",value:"App sandbox");LabeledContent("Offline",value:"Core always available");LabeledContent("Search",value:"Local lexical & fuzzy");LabeledContent("AI",value:"No model required");LabeledContent("Version",value:"0.3.9");Text("Data stays on this device. Speech requires on-device recognition. No telemetry is collected.").font(.footnote).foregroundStyle(Design.muted)}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("System health") }
}

struct NativeFocusChoice:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {NavigationStack {List {Section {Text("Choose where you want more attention. Important deadlines stay visible.").font(.subheadline).foregroundStyle(Design.muted).listRowSeparator(.hidden);choice("all","Balanced");ForEach(Catalog.spaces){choice($0.id,$0.name)}}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Focus on a space").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}}}
    func choice(_ id:String,_ label:String)->some View {Button{store.setFocus(id);if store.preferences.focus == id{dismiss()}}label:{HStack{Text(label).foregroundStyle(Design.ink);Spacer();if store.preferences.focus == id{Image(systemName:"checkmark").foregroundStyle(Design.ink)}}.frame(minHeight:44)}.listRowSeparator(.hidden)}
}
