import Foundation
public enum BeatAudio {
    // A full beat includes its silence, so AVAudioPlayerNode loops on the audio clock.
    public static func samples(bpm:Int,sampleRate:Double=44100)->[Float] {
        let tempo=min(240,max(30,bpm));let frames=Int(sampleRate*60/Double(tempo));let clickFrames=min(frames,Int(sampleRate*0.05))
        var result=[Float](repeating:0,count:frames)
        for index in 0..<clickFrames {let time=Double(index)/sampleRate;result[index]=Float(sin(2 * .pi * 1000 * time)*0.35*exp(-time*150))}
        return result
    }
}
