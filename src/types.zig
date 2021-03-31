pub const Fd = enum(u32) {
    stdin = 0,
    stdout = 1,
    stderr = 2,
    _,
};
pub const Mode = enum(u32) { _ };

pub const Signal = enum {
    /// Hangup detected on controlling terminal or death of controlling process
    hup = 1,

    /// Interrupt from keyboard
    int = 2,

    /// Quit from keyboard
    quit = 3,

    /// Illegal Instruction
    ill = 4,

    /// Trace/breakpoint trap
    trap = 5,

    /// Abort signal from abort(3)
    abrt = 6,

    /// Bus error (bad memory access)
    bus = 7,

    /// Floating-point exception
    fpe = 8,

    /// Kill signal
    kill = 9,

    /// User-defined signal 1
    usr1 = 10,

    /// Invalid memory reference
    segv = 11,

    /// User-defined signal 2
    usr2 = 12,

    /// Broken pipe: write to pipe with no readers; see pipe(7)
    pipe = 13,

    /// Timer signal from alarm(2)
    alrm = 14,

    /// Termination signal
    term = 15,
};
