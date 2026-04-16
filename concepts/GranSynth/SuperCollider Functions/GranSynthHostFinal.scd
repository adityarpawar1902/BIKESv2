
(
s.waitForBoot({
    // --- 1. Variables ---
    var path, rootNote;
    var currentDens = 200;
    var currentDur = 0.07;
    var currentPos = 0.1;

    ~host = "1"; // Hardcoded for bikes1
    rootNote = 36;

    ~absolutePrefix = thisProcess.nowExecutingPath.dirname.dirname;
    path = ~absolutePrefix +/+ "Audio Files" +/+ "AtmosphericC2.wav";
    b = Buffer.readChannel(s, path, channels: [0]);

    // --- 2. SynthDef ---
    SynthDef.new(\gs, {
        arg sync=0, dens=60, dur=0.4, durRand=0.5, durHz=0.3, buf=0,
        rate=1, pos=0.1, posSpeed=0.1, posRand=0.05,
        grainEnv=(-1), pan=0, panHz=0.1, panRand=0,
        atk=0.5, rel=2, gate=1, amp=0.3, out=0;

        var sig, env, trigger, durCtrl, posCtrl, panCtrl;

        env = EnvGen.ar(Env.asr(atk, 1, rel), gate, doneAction: 2);
        trigger = Select.ar(sync, [Dust.ar(dens ! 2), Impulse.ar(dens ! 2)]);
        durCtrl = dur * LFNoise1.kr(durHz ! 2).exprange(1 - durRand, 1 + durRand);
        posCtrl = Phasor.ar(0, posSpeed * BufRateScale.ir(buf), 0, BufSamples.ir(buf) - 1);
        posCtrl = posCtrl + LFNoise1.ar(100 ! 2).bipolar(posRand * SampleRate.ir);
        posCtrl = (posCtrl / BufSamples.ir(buf) + pos).wrap(0, 1);
        panCtrl = pan + LFNoise1.kr(panHz ! 2).bipolar(panRand);

        sig = GrainBuf.ar(2, trigger, durCtrl, buf, rate, posCtrl, 2, panCtrl, grainEnv);
        Out.ar(out, sig * env * amp);
    }).add;

    s.sync;

    // --- 3. Context Lookups ---
    ~noteMap = ( 'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11 );
    ~scales  = (
        'Major':      [0, 2, 4, 5, 7, 9, 11],
        'Minor':      [0, 2, 3, 5, 7, 8, 10],
        'Dorian':     [0, 2, 3, 5, 7, 9, 10],
        'Mixolydian': [0, 2, 4, 5, 7, 9, 10]
    );

    ~activeSynth = nil;

    ~playNote = { |rootName, scaleName, degree|
        var rootMidi, noteMidi, ratio;
        rootMidi = rootNote + ~noteMap[rootName.asSymbol];
        noteMidi = rootMidi + ~scales[scaleName.asSymbol][degree.asInteger - 1];
        ratio = (noteMidi - rootNote).midiratio;

        if (~activeSynth.notNil && { ~activeSynth.isPlaying }) {
            ~activeSynth.set(\rate, ratio);
        } {
            ~activeSynth = Synth(\gs, [
                \buf, b, \rate, ratio, \dens, currentDens,
                \dur, currentDur, \pos, currentPos, \amp, 0.2, \gate, 1
            ]).register;
        };
    };

    // --- 4. Network ---
    fork {
        p = P2PSC();
        p.sync;
        p.setName(~host);
        p.sync;
        0.2.wait;
        p.sync;
        "✅ HOST P2PSC Ready! Node: %".format(~host).postln;
    };

    // --- 5. Broadcast to Network ---
    OSCdef(\pygameRelay, { |msg|
        var root    = msg[1];
        var scale   = msg[2];
        var degree  = msg[3];

        if(degree.asInteger > 0) {
            { ~playNote.value(root, scale, degree) }.defer;
        } {
            if(~activeSynth.notNil) { ~activeSynth.set(\gate, 0); ~activeSynth = nil; };
        };

        if(p.notNil) {
            fork {
                p.getPeers.do { |peerName|
                    var peerStr = peerName.asString;
                    if(peerStr.notEmpty and: { peerStr != ~host.asString }) {
                        try {
                            NetAddr(peerStr, 57121).sendMsg("/remoteChord", root, scale, degree);
                            NetAddr(peerStr, 57120).sendMsg("/remoteChord", root, scale, degree);
                        } { |e| ("Failed to reach " ++ peerStr).postln; };
                    };
                };
            };
        };
    }, "/chord");
});
)