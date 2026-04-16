s.waitForBoot({
    // assign host + peer from machine name
    ~host = "";
    ~peer = "";

    if(("whoami".unixCmdGetStdOut).contains("bikes1")) {
        ~host = "1";
        ~peer = "2";
    };
    if(("whoami".unixCmdGetStdOut).contains("bikes2")) {
        ~host = "2";
        ~peer = "3";
    };
    if(("whoami".unixCmdGetStdOut).contains("bikes3")) {
        ~host = "3";
        ~peer = "4";
    };
    if(("whoami".unixCmdGetStdOut).contains("bikes4")) {
        ~host = "4";
        ~peer = "1";
    };

    fork {
        p = P2PSC();
        p.sync;
        p.setName(~host);
        p.sync;

        ~lastRelayTime = nil;
        ~jamRate = 1;
        ~jamGap = 0.01;
        ~relayAmp = 0.22;

        // relay path
        p.addPath({ |msg|
            var freq = msg[1].asFloat;
            var now = Main.elapsedTime;

            /*
            if(~lastRelayTime.notNil) {
                ("[RELAY DELTA] " ++ (now - ~lastRelayTime)).postln;
            };
            ~lastRelayTime = now;
            ("[RECEIVED RELAY] " ++ msg.asString ++ " at " ++ now).postln;
            */

            {
                SinOsc.ar(84.midicps, 0, ~relayAmp) *
                EnvGen.kr(
                    Env.perc(0.001, 0.02),
                    doneAction: 2
                )
            }.play;

            // forward to assigned peer in ring
            p.sendMsg("/" ++ ~peer ++ "/relay", freq);
        }, "/relay");

        // jam path
        p.addPath({ |msg|
            // do nothing
        }, "/jam");

        // jammer
        ~jammer = Routine({
            loop {
                ~jamRate.do {
                    p.sendMsg("/" ++ ~peer ++ "/jam", 9, 8, 7, 6, 5, 4, 3, 2);
                };
                ~jamGap.wait;
            }
        }).play;

        ("ready: host=" ++ ~host ++ " peer=" ++ ~peer).postln;
    };
});

AppClock.sched(0, {
    var min = 0.1;
    var max = 10;
    var skew = 0.2;
    var screen, winW, winH, sliderW, sliderH, buttonW, buttonH, centerX;

    screen = Window.screenBounds;

    winW = screen.width;
    winH = screen.height;

    w = Window("Jam Rate Control", screen).front;
    w.fullScreen;

    sliderW = winW * 0.7;
    sliderH = 30;
    buttonW = winW * 0.3;
    buttonH = 40;

    centerX = winW / 2;

    Slider(w, Rect(
        centerX - (sliderW / 2),
        (winH / 2) - 50,
        sliderW,
        sliderH
    ))
    .value_(0.1)
    .action_({ |sl|
        var curved, val;

        curved = sl.value.pow(skew);
        val = curved.linexp(0.0001, 1, min, max);

        ~jamRate = val.asInteger.max(1);
        ("jamRate: " ++ ~jamRate).postln;
    });

    Button(w, Rect(
        centerX - (buttonW / 2),
        (winH / 2) + 10,
        buttonW,
        buttonH
    ))
    .states_([
        ["Send Relay 440", Color.black, Color.green]
    ])
    .action_({
        p.sendMsg("/" ++ ~peer ++ "/relay", 440);
        ("Sent /" ++ ~peer ++ "/relay 440").postln;
    });
});