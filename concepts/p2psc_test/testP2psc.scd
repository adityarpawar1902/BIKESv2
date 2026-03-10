(
// Auto-name from OS username
~myName = "whoami".unixCmdGetStdOut.drop(-1);
~startPing = (~myName == "bikes1");
~delay = 1.0;

// Set your ring here
~ring = ["bikes1","bikes2", "bikes3"];

// next-in-ring helper
~nextInRing = { |name|
    var i = ~ring.indexOfEqual(name.asString);
    if(i.isNil) { ~ring[0] } { ~ring.wrapAt(i + 1) };
};

fork {
    var p;

    p = P2PSC(); p.sync;
    p.setName(~myName); p.sync;

    ("Node started: " ++ p.name).postln;
    ("Ready. username=" ++ ~myName ++ " startPing=" ++ ~startPing).postln;

    // Receiver: print + forward (safe: no yielding calls here)
    p.addPath({ |msg|
        var from, nextPeer;

        from = msg[1].asString;
        nextPeer = ~nextInRing.(p.name);

        ("[" ++ p.name ++ "] received /ping from " ++ from).postln;
        ("[" ++ p.name ++ "] forwarding -> " ++ nextPeer).postln;

        p.sendMsg("/" ++ nextPeer ++ "/ping", p.name);
    }, "/ping");

    // Initial sender (bikes1 only)
    if(~startPing) {
        fork {
            ~delay.wait;
            ("[" ++ p.name ++ "] starting ping chain -> " ++ ~nextInRing.(p.name)).postln;
            p.sendMsg("/" ++ ~nextInRing.(p.name) ++ "/ping", p.name);
        };
    };
};
)