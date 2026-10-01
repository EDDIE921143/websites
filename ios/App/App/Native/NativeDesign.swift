import SwiftUI
import EdizCore

enum Design {
    static let background=Color(red:0.035,green:0.04,blue:0.047)
    static let surface=Color(red:0.085,green:0.095,blue:0.11)
    static let raised=Color(red:0.135,green:0.15,blue:0.17)
    static let ink=Color(red:0.94,green:0.94,blue:0.92)
    static let muted=Color(red:0.62,green:0.65,blue:0.68)
    static let accent=Color(red:0.44,green:0.62,blue:0.78)
    static func color(_ hex:UInt32)->Color { Color(red:Double((hex >> 16)&255)/255,green:Double((hex >> 8)&255)/255,blue:Double(hex&255)/255) }
}
struct SpaceMark: View {
    var space:SpaceDefinition
    var body:some View {
        Group { if space.id == "school" { Image(systemName:"book.closed").font(.body) } else { Text(space.mark).font(space.id == "moshia" ? .system(.title2,design:.serif,weight:.regular) : .system(.body,weight:.medium)) } }
            .foregroundStyle(Design.color(space.color)).frame(width:38,height:38).background(Design.color(space.color).opacity(0.12),in:RoundedRectangle(cornerRadius:10))
    }
}
struct Surface<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View { content.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:14)) }
}
struct ActionStyle:ButtonStyle {
    var primary=false
    func makeBody(configuration:Configuration)->some View { configuration.label.font(.subheadline.weight(.medium)).frame(maxWidth:.infinity).frame(minHeight:46).foregroundStyle(primary ? Design.background:Design.ink).background(primary ? Design.ink:Design.raised,in:RoundedRectangle(cornerRadius:10)).opacity(configuration.isPressed ? 0.75:1) }
}
struct SpaceRoute:Hashable { let id:String;var kind:String?=nil }
struct OSNavigation<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {
        NavigationStack {
            content.navigationDestination(for:Record.self){NativeEditor(record:$0)}
                .navigationDestination(for:SpaceRoute.self){NativeSpace(route:$0)}
                .toolbar { ToolbarItem(placement:.topBarTrailing) { NavigationLink { NativeSettings() } label:{ Image(systemName:"slider.horizontal.3").font(.body).foregroundStyle(Design.muted).frame(minWidth:44,minHeight:44) }.accessibilityLabel("Settings and backup") } }
        }.tint(Design.accent)
    }
}
struct RecordRow:View {
    @EnvironmentObject var store:NativeStore
    let record:Record
    var body:some View {
        HStack(spacing:13) {
            if record.actionable { Button { store.complete(record) } label:{ Image(systemName:"square").font(.title3).foregroundStyle(Design.muted).frame(width:44,height:44) }.buttonStyle(.borderless).accessibilityLabel("Complete \(record.title)") }
            NavigationLink(value:record) {
                VStack(alignment:.leading,spacing:5) {
                    Text(record.title).font(.body).foregroundStyle(Design.ink)
                    HStack(spacing:7) {
                        Text(Catalog.space(record.space).name)
                        if let due=Time.date(record.due) { Text(due,format:.dateTime.month(.abbreviated).day()) }
                        if let minutes=record.duration { Text("\(minutes) min") }
                    }.font(.caption).foregroundStyle(Design.muted)
                }.frame(maxWidth:.infinity,alignment:.leading)
                Image(systemName:"chevron.right").font(.caption.weight(.medium)).foregroundStyle(Design.muted)
            }.buttonStyle(.plain)
        }.padding(.vertical,7)
    }
}
struct QuietEmpty:View {
    var title:String
    var message:String
    var body:some View { VStack(alignment:.leading,spacing:9){Text(title).font(.headline.weight(.medium));Text(message).font(.subheadline).foregroundStyle(Design.muted)}.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,15) }
}
