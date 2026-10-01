import SwiftUI
import EdizCore
import UIKit

enum Design {
    static let background=Color(red:0.055,green:0.051,blue:0.043)
    static let surface=Color(red:0.13,green:0.122,blue:0.11)
    static let raised=Color(red:0.19,green:0.18,blue:0.16)
    static let ink=Color(red:0.94,green:0.92,blue:0.87)
    static let muted=Color(red:0.68,green:0.66,blue:0.62)
    static let accent=ink
    static func font(_ size:CGFloat,weight:String="Medium",relativeTo:Font.TextStyle = .body)->Font { .custom("AvenirNext-"+weight,size:size,relativeTo:relativeTo) }
    static func color(_ hex:UInt32)->Color { Color(red:Double((hex >> 16)&255)/255,green:Double((hex >> 8)&255)/255,blue:Double(hex&255)/255) }
}
struct SpaceMark: View {
    var space:SpaceDefinition
    var symbol:String { switch space.id { case "ejj":return "rectangle.3.group.fill";case "band":return "waveform";case "moshia":return "book.closed.fill";case "school":return "graduationcap.fill";default:return "person.fill" } }
    var body:some View { Image(systemName:symbol).font(.system(size:21,weight:.medium)).foregroundStyle(Design.color(space.color)).frame(width:36,height:40).accessibilityHidden(true) }
}
struct GlassAction<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {
        if #available(iOS 26.0,*) { content.buttonStyle(.glass).tint(Design.ink) }
        else { content.buttonStyle(ActionStyle()) }
    }
}
struct Surface<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View { content.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:14)) }
}
struct ActionStyle:ButtonStyle {
    var primary=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(Design.font(15)).padding(.horizontal,18).frame(minHeight:46).foregroundStyle(Design.ink)
            .background(.regularMaterial,in:Capsule()).shadow(color:.black.opacity(0.18),radius:8,y:4)
            .scaleEffect(configuration.isPressed ? 0.97:1).opacity(configuration.isPressed ? 0.8:1)
    }
}
struct SpaceRoute:Hashable { let id:String;var kind:String?=nil }
struct OSNavigation<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {
        NavigationStack {
            content.navigationDestination(for:EdizCore.Record.self){NativeEditor(record:$0)}
                .navigationDestination(for:SpaceRoute.self){NativeSpace(route:$0)}
                .toolbar { ToolbarItem(placement:.topBarTrailing) { NavigationLink { NativeSettings() } label:{ Image(systemName:"slider.horizontal.3").font(.body).foregroundStyle(Design.muted).frame(minWidth:44,minHeight:44) }.accessibilityLabel("Settings and backup") } }
        }.tint(Design.accent)
    }
}
struct RecordRow:View {
    @EnvironmentObject var store:NativeStore
    let record:EdizCore.Record
    var body:some View {
        HStack(spacing:13) {
            if record.actionable { Button { store.complete(record) } label:{ Image(systemName:"square").font(.title3).foregroundStyle(Design.muted).frame(width:44,height:44) }.buttonStyle(.borderless).accessibilityLabel("Complete \(record.title)") }
            NavigationLink(value:record) {
                VStack(alignment:.leading,spacing:5) {
                    Text(record.title).font(Design.font(17,weight:"Regular")).foregroundStyle(Design.ink)
                    HStack(spacing:7) {
                        Text(Catalog.space(record.space).name)
                        if let due=Time.date(record.due) { Text(due,format:.dateTime.month(.abbreviated).day()) }
                        if let minutes=record.duration { Text("\(minutes) min") }
                    }.font(.caption).foregroundStyle(Design.muted)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.buttonStyle(.plain)
        }.padding(.vertical,7)
    }
}
struct QuietEmpty:View {
    var title:String
    var message:String
    var body:some View { VStack(alignment:.leading,spacing:9){Text(title).font(.headline.weight(.medium));Text(message).font(.subheadline).foregroundStyle(Design.muted)}.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,15) }
}

// Public UIKit APIs preserve the system's native liquid-glass tab bar.
struct NativeTabScrubber:UIViewRepresentable {
    @Binding var selection:Int
    func makeCoordinator()->Coordinator { Coordinator(selection:$selection) }
    func makeUIView(context:Context)->UIView { let view=UIView();view.isUserInteractionEnabled=false;return view }
    func updateUIView(_ view:UIView,context:Context) {
        context.coordinator.selection=$selection
        DispatchQueue.main.asyncAfter(deadline:.now()+0.25) { context.coordinator.attach(from:view.window?.rootViewController) }
    }
    final class Coordinator:NSObject,UIGestureRecognizerDelegate {
        var selection:Binding<Int>
        weak var bar:UITabBar?
        var pan:UIPanGestureRecognizer?
        init(selection:Binding<Int>){self.selection=selection}
        func controller(_ root:UIViewController?)->UITabBarController? {
            guard let root else{return nil};if let tabs=root as? UITabBarController{return tabs}
            for child in root.children { if let tabs=controller(child){return tabs} };return nil
        }
        func attach(from root:UIViewController?) {
            guard let newBar=controller(root)?.tabBar,bar !== newBar else{return}
            if let pan{bar?.removeGestureRecognizer(pan)}
            let gesture=UIPanGestureRecognizer(target:self,action:#selector(scrub(_:)))
            gesture.delegate=self;gesture.cancelsTouchesInView=false;newBar.addGestureRecognizer(gesture);bar=newBar;pan=gesture
        }
        func gestureRecognizerShouldBegin(_ gesture:UIGestureRecognizer)->Bool {
            guard let pan=gesture as? UIPanGestureRecognizer,let bar else{return false}
            let v=pan.velocity(in:bar);return abs(v.x)>abs(v.y)
        }
        func gestureRecognizer(_ gesture:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith other:UIGestureRecognizer)->Bool{true}
        @objc func scrub(_ gesture:UIPanGestureRecognizer) {
            guard let bar,let count=bar.items?.count,count>0,bar.bounds.width>0 else{return}
            let index=min(count-1,max(0,Int(gesture.location(in:bar).x/bar.bounds.width*CGFloat(count))))
            if selection.wrappedValue != index{selection.wrappedValue=index;UISelectionFeedbackGenerator().selectionChanged()}
        }
    }
}
