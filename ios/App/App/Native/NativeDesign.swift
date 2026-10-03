import SwiftUI
import EdizCore
import UIKit

enum Design {
    static let background=Color(red:0.045,green:0.052,blue:0.065)
    static let surface=Color(red:0.105,green:0.116,blue:0.133)
    static let raised=Color(red:0.16,green:0.176,blue:0.196)
    static let ink=Color(red:0.94,green:0.92,blue:0.87)
    static let muted=Color(red:0.67,green:0.70,blue:0.75)
    static let accent=ink
    static let glassLettering=LinearGradient(colors:[Color.white,ink,Color(red:0.80,green:0.79,blue:0.74),ink],startPoint:.topLeading,endPoint:.bottomTrailing)
    static func font(_ size:CGFloat,weight:String="Medium",relativeTo:Font.TextStyle = .body)->Font {
        let style:Font.TextStyle = relativeTo != .body ? relativeTo : size <= 12 ? .caption : size <= 14 ? .footnote : size <= 16 ? .subheadline : size <= 18 ? .body : size <= 20 ? .headline : size <= 24 ? .title3 : size <= 28 ? .title2 : size <= 34 ? .title : .largeTitle
        return .system(style,design:.default).weight(weight == "Regular" ? .regular:weight == "DemiBold" ? .semibold:.medium)
    }
    static func color(_ hex:UInt32)->Color { Color(red:Double((hex >> 16)&255)/255,green:Double((hex >> 8)&255)/255,blue:Double(hex&255)/255) }
}
enum WorkspaceTheme {
    static func base(_ scope:String)->Color {
        switch scope {
        case "ejj":return Color(red:0.055,green:0.070,blue:0.085)
        case "band":return Color(red:0.13,green:0.035,blue:0.075)
        case "moshia":return Color(red:0.14,green:0.105,blue:0.065)
        case "school":return Color(red:0.025,green:0.105,blue:0.09)
        case "personal":return Color(red:0.115,green:0.075,blue:0.12)
        case "capture":return Color(red:0.095,green:0.105,blue:0.13)
        case "spaces":return Color(red:0.045,green:0.065,blue:0.10)
        default:return Design.background
        }
    }
    static func accent(_ scope:String)->Color {
        switch scope {
        case "ejj":return Color(red:0.64,green:0.72,blue:0.77)
        case "band":return Color(red:1,green:0.43,blue:0.51)
        case "moshia":return Color(red:0.89,green:0.72,blue:0.43)
        case "school":return Color(red:0.40,green:0.85,blue:0.67)
        case "personal":return Color(red:0.78,green:0.65,blue:0.95)
        default:return Design.ink
        }
    }
}
private struct WorkspaceFocusKey:EnvironmentKey {static let defaultValue="all"}
extension EnvironmentValues {var edizWorkspaceFocus:String {get{self[WorkspaceFocusKey.self]}set{self[WorkspaceFocusKey.self]=newValue}}}
struct FocusLogo:View {
    let scope:String
    var body:some View {
        Image("EdizLogo").resizable().scaledToFit().overlay {
            if scope != "all" {GeometryReader{geometry in
                RoundedRectangle(cornerRadius:geometry.size.width*0.012)
                    .fill(WorkspaceTheme.accent(scope))
                    .frame(width:geometry.size.width*0.307,height:geometry.size.height*0.053)
                    .position(x:geometry.size.width*0.457,y:geometry.size.height*0.5)
            }}
        }.accessibilityLabel("Ediz OS logo").accessibilityValue(scope == "all" ? "Balanced":Catalog.space(scope).name).accessibilityIdentifier("focus-logo")
    }
}
struct AppBackdrop:View {
    var scope:String = "all"
    @Environment(\.edizWorkspaceFocus) private var focus
    var palette:String{scope == "all" ? focus:scope}
    var accent:Color {WorkspaceTheme.accent(palette)}
    var body:some View {
        ZStack {
            WorkspaceTheme.base(palette)
            LinearGradient(colors:[accent.opacity(palette == "all" ? 0.035:0.07),.clear,Color.black.opacity(0.34)],startPoint:.topLeading,endPoint:.bottomTrailing)
            Canvas { context,size in
                var pattern=Path()
                switch palette {
                case "ejj":
                    // Blueprints: a broad technical grid, with sparse registration marks.
                    let step:CGFloat=72
                    for x in stride(from:CGFloat(0),through:size.width,by:step){pattern.move(to:CGPoint(x:x,y:0));pattern.addLine(to:CGPoint(x:x,y:size.height))}
                    for y in stride(from:CGFloat(0),through:size.height,by:step){pattern.move(to:CGPoint(x:0,y:y));pattern.addLine(to:CGPoint(x:size.width,y:y))}
                    context.stroke(pattern,with:.color(accent.opacity(0.14)),lineWidth:0.7)
                    var markers=Path()
                    for y in stride(from:CGFloat(72),through:size.height,by:144){for x in stride(from:CGFloat(72),through:size.width,by:144){markers.move(to:CGPoint(x:x-5,y:y));markers.addLine(to:CGPoint(x:x+5,y:y));markers.move(to:CGPoint(x:x,y:y-5));markers.addLine(to:CGPoint(x:x,y:y+5))}}
                    context.stroke(markers,with:.color(accent.opacity(0.25)),lineWidth:1)
                case "band":
                    // Stage spotlights and large vinyl grooves, rather than repeated icons.
                    for index in 0..<3 {let x=size.width*CGFloat(index+1)/4;var beam=Path();beam.move(to:CGPoint(x:x,y:0));beam.addLine(to:CGPoint(x:x-110,y:size.height));beam.addLine(to:CGPoint(x:x+110,y:size.height));beam.closeSubpath();context.fill(beam,with:.linearGradient(Gradient(colors:[accent.opacity(0.09),.clear]),startPoint:CGPoint(x:x,y:0),endPoint:CGPoint(x:x,y:size.height)))}
                    for radius in stride(from:CGFloat(110),through:330,by:28){pattern.addEllipse(in:CGRect(x:size.width-radius,y:size.height*0.62-radius,width:radius*2,height:radius*2))}
                    context.stroke(pattern,with:.color(accent.opacity(0.12)),lineWidth:1)
                case "moshia":
                    // A book's double folio border and gently drawn landscape at its foot.
                    pattern.addRoundedRect(in:CGRect(x:14,y:24,width:max(0,size.width-28),height:max(0,size.height-48)),cornerSize:CGSize(width:4,height:4))
                    pattern.addRoundedRect(in:CGRect(x:21,y:31,width:max(0,size.width-42),height:max(0,size.height-62)),cornerSize:CGSize(width:2,height:2))
                    for row in 0..<5 {let y=size.height*0.68+CGFloat(row)*30;pattern.move(to:CGPoint(x:20,y:y));pattern.addCurve(to:CGPoint(x:size.width-20,y:y+90),control1:CGPoint(x:size.width*0.35,y:y-80),control2:CGPoint(x:size.width*0.68,y:y+150))}
                    context.stroke(pattern,with:.color(accent.opacity(0.16)),lineWidth:0.8)
                case "school":
                    for y in stride(from:CGFloat(40),through:size.height,by:38){pattern.move(to:CGPoint(x:0,y:y));pattern.addLine(to:CGPoint(x:size.width,y:y))}
                    context.stroke(pattern,with:.color(accent.opacity(0.13)),lineWidth:0.7)
                    var margin=Path();margin.move(to:CGPoint(x:34,y:0));margin.addLine(to:CGPoint(x:34,y:size.height));context.stroke(margin,with:.color(Color(red:0.86,green:0.54,blue:0.43).opacity(0.22)),lineWidth:1)
                case "capture":
                    for y in stride(from:CGFloat(140),through:size.height,by:180){pattern.move(to:CGPoint(x:24,y:y));pattern.addLine(to:CGPoint(x:size.width-24,y:y))}
                    context.stroke(pattern,with:.color(accent.opacity(0.07)),lineWidth:1)
                case "spaces":
                    for y in stride(from:CGFloat(0),through:size.height,by:120){for x in stride(from:CGFloat(0),through:size.width,by:120){pattern.addRoundedRect(in:CGRect(x:x+14,y:y+14,width:92,height:92),cornerSize:CGSize(width:20,height:20))}}
                    context.stroke(pattern,with:.color(accent.opacity(0.04)),lineWidth:1)
                default:
                    for offset in stride(from:CGFloat(-100),through:500,by:80){pattern.move(to:CGPoint(x:size.width+offset,y:-80));pattern.addCurve(to:CGPoint(x:-120,y:size.height*0.8+offset),control1:CGPoint(x:size.width*0.12+offset,y:size.height*0.18),control2:CGPoint(x:size.width*1.3,y:size.height*0.58+offset))}
                    context.stroke(pattern,with:.color(accent.opacity(palette == "personal" ? 0.12:0.065)),lineWidth:0.8)
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct WorkspacePanel:View {
    var scope:String
    var body:some View {LinearGradient(colors:[WorkspaceTheme.accent(scope).opacity(0.15),WorkspaceTheme.base(scope).opacity(0.96)],startPoint:.topLeading,endPoint:.bottomTrailing)}
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
private struct EdizCompactKey:EnvironmentKey { static let defaultValue=false }
extension EnvironmentValues {
    var edizCompact:Bool { get { self[EdizCompactKey.self] } set { self[EdizCompactKey.self]=newValue } }
}
struct Surface<Content:View>:View {
    @Environment(\.edizCompact) private var compact
    @ViewBuilder var content:Content
    var body:some View { content.padding(compact ? 12:22).frame(maxWidth:.infinity,alignment:.leading).background(compact ? Design.raised:Design.surface,in:RoundedRectangle(cornerRadius:compact ? 10:22)).overlay{RoundedRectangle(cornerRadius:compact ? 10:22).strokeBorder(Design.ink.opacity(0.055),lineWidth:1).allowsHitTesting(false)} }
}
struct ControlMaterial:ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reducedTransparency
    func body(content:Content)->some View {
        if reducedTransparency { content.background(Design.raised,in:Capsule()) }
        else if #available(iOS 26.0,*) { content.glassEffect(.regular.interactive(),in:Capsule()) }
        else { content.background(.regularMaterial,in:Capsule()) }
    }
}
struct ActionStyle:ButtonStyle {
    var primary=false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(Design.font(15)).padding(.horizontal,18).frame(minHeight:46).foregroundStyle(Design.ink)
            .modifier(ControlMaterial())
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.97:1)
            .opacity(!enabled ? 0.4:configuration.isPressed ? 0.85:1)
    }
}
struct SpaceRoute:Hashable { let id:String;var kind:String?=nil }
struct OSNavigation<Content:View>:View {
    @EnvironmentObject var store:NativeStore
    @ViewBuilder var content:Content
    var body:some View {
        NavigationStack {
            content.navigationDestination(for:EdizCore.Record.self){NativeEditor(record:$0)}
                .navigationDestination(for:SpaceRoute.self){NativeSpace(route:$0)}
                .toolbar { ToolbarItem(placement:.topBarTrailing) { NavigationLink { NativeSettings() } label:{ Image(systemName:"slider.horizontal.3").font(.body).foregroundStyle(Design.muted).frame(minWidth:44,minHeight:44) }.accessibilityLabel("Settings and backup").walkthroughTarget("settings",session:store.walkthrough) } }
        }.tint(Design.accent)
    }
}
struct RecordRow:View {
    @EnvironmentObject var store:NativeStore
    let record:EdizCore.Record
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body:some View {
        HStack(spacing:13) {
            if record.actionable { Button { withAnimation(reducedMotion ? nil:.easeInOut(duration:0.25)){store.complete(record)} } label:{ Image(systemName:"square").font(.title3).foregroundStyle(Design.muted).frame(width:44,height:44) }.buttonStyle(.borderless).accessibilityLabel("Complete \(record.title)") }
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
        }.padding(.vertical,store.preferences.density == "compact" ? 3:7).transition(.opacity.combined(with:.scale(scale:0.97)))
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
        var candidate:Int?
        let feedback=UISelectionFeedbackGenerator()
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
            switch gesture.state {
            case .began: candidate=index;feedback.prepare()
            case .changed: if candidate != index {candidate=index;feedback.selectionChanged()}
            case .ended: candidate=nil;if selection.wrappedValue != index {selection.wrappedValue=index}
            case .cancelled,.failed: candidate=nil
            default: break
            }
        }
    }
}


struct WorkspaceEntrance:ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var entered=false
    func body(content:Content)->some View {
        content.opacity(reducedMotion || entered ? 1:0)
            .offset(y:reducedMotion || entered ? 0:12)
            .onAppear{withAnimation(reducedMotion ? nil:.spring(duration:0.42,bounce:0.12)){entered=true}}
            .onDisappear{entered=false}
    }
}
struct CompletionToast:View {
    let undo:()->Void
    let dismiss:()->Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var appeared=false
    var body:some View {
        HStack(spacing:12){
            ZStack {
                Circle().stroke(Design.ink.opacity(0.15),lineWidth:2)
                Circle().trim(from:0,to:appeared ? 1:0).stroke(Design.ink,lineWidth:2).rotationEffect(.degrees(-90))
                Image(systemName:"checkmark").font(.system(size:15,weight:.semibold)).scaleEffect(appeared ? 1:0.5).opacity(appeared ? 1:0)
                ForEach(0..<6){index in Capsule().fill(Design.ink).frame(width:2,height:5).offset(y:appeared ? -25:-17).rotationEffect(.degrees(Double(index)*60)).opacity(appeared ? 0:1)}
            }.frame(width:32,height:32).accessibilityHidden(true)
            Text("Completed").font(.subheadline.weight(.medium))
            Spacer()
            Button("Undo",action:undo).font(.subheadline.weight(.medium)).frame(minHeight:44)
            Button(action:dismiss){Image(systemName:"xmark").frame(width:32,height:44)}.accessibilityLabel("Dismiss completion")
        }.padding(.horizontal,16).padding(.vertical,4).background(.regularMaterial,in:RoundedRectangle(cornerRadius:18))
            .onAppear{withAnimation(reducedMotion ? nil:.easeOut(duration:0.65)){appeared=true}}
            .accessibilityElement(children:.contain).accessibilityIdentifier("completion-feedback")
    }
}
struct BrandedRefresh:ViewModifier {
    @EnvironmentObject var store:NativeStore
    @Environment(\.edizWorkspaceFocus) private var focus
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var refreshing=false
    @State private var showing=false
    @State private var failed=false
    func body(content:Content)->some View {
        content.refreshable {
            guard !refreshing else{return}
            failed=false;refreshing=true
            withAnimation(reducedMotion ? nil:.easeOut(duration:0.18)){showing=true}
            let succeeded=await store.refresh()
            try? await Task.sleep(for:.milliseconds(450))
            failed = !succeeded
            refreshing=false
            try? await Task.sleep(for:.milliseconds(550))
            withAnimation(reducedMotion ? nil:.easeOut(duration:0.2)){showing=false}
        }.overlay(alignment:.top){
            if showing {
                HStack(spacing:10){
                    BrandedRefreshLogo(scope:focus,refreshing:refreshing)
                    Text(refreshing ? "Refreshing your workspace…":failed ? "Refresh needs a connection":"Up to date").font(.caption.weight(.medium))
                    if !refreshing{Image(systemName:failed ? "wifi.slash":"checkmark").font(.caption.weight(.semibold))}
                }.padding(.horizontal,16).padding(.vertical,12).background(.regularMaterial,in:Capsule()).padding(.top,8)
                    .transition(.move(edge:.top).combined(with:.opacity)).accessibilityIdentifier("workspace-refresh-status").allowsHitTesting(false)
            }
        }
    }
}

struct BrandedRefreshLogo:View {
    let scope:String
    let refreshing:Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var rotating=false
    var body:some View {
        FocusLogo(scope:scope).frame(width:28,height:28)
            .rotationEffect(.degrees(rotating && !reducedMotion ? 360:0))
            .animation(reducedMotion ? nil:refreshing ? .linear(duration:1.1).repeatForever(autoreverses:false):.easeOut(duration:0.2),value:rotating)
            .onAppear{rotating=refreshing}.onChange(of:refreshing){_,value in rotating=value}
    }
}
