import Foundation

/// Maps measured audio power to a readable visual range, without lifting silence.
public enum AudioMeter {
    public static func level(rms:Float)->Float {
        guard rms.isFinite,rms>0 else{return 0}
        return level(decibels:20*log10(rms))
    }
    public static func level(decibels:Float)->Float {
        guard decibels.isFinite else{return 0}
        return min(1,max(0,(decibels+55)/43))
    }
    public static func smooth(previous:Float,target:Float)->Float {
        let target=min(1,max(0,target))
        return previous+(target-previous)*(target>previous ? 0.72:0.22)
    }
}
