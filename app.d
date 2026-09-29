import core.volatile : volatileLoad;
import core.thread;
import core.time;
import ldc.llvmasm : __asm;
import std.conv : to;
import std.traits : isIntegral, isPointer, isSigned, Parameters;

enum emitProbe(alias probeDecl, args...) = ()
{
    alias Provider = __traits(parent, probeDecl);
    alias Params = Parameters!probeDecl;

    static assert(is(Provider == interface));
    static assert(args.length == Params.length);
    static foreach (T; Params)
        static assert(isIntegral!T || isPointer!T);

    enum provider = __traits(identifier, Provider);
    enum probe = __traits(identifier, probeDecl);
    enum semaName = "__usdt_sema_" ~ provider ~ "_" ~ probe;
    enum paramsOf = "Parameters!(" ~ __traits(fullyQualifiedName, probeDecl) ~ ")";

    string spec, cons, decls, operands;
    // ループの最初がi=0なのを利用して構築
    static foreach (i, T; Params)
    {
        spec ~= (i ? " " : "") ~ (isSigned!T ? "-" : "") ~ T.sizeof.to!string ~ "@$" ~ i.to!string;
        cons ~= i ? ",r" : "r";
        decls ~= paramsOf ~ "[" ~ i.to!string ~ "] __a" ~ i.to!string ~ " = (" ~ args[i] ~ ");\n";
        operands ~= ", __a" ~ i.to!string;
    }

    return `{
    pragma(mangle, "` ~ semaName ~`")
    extern (C) extern __gshared ushort sema;

    if (volatileLoad(&sema) != 0)
    {
        ` ~ decls ~ `
        __asm("
990:
        nop
.ifndef ` ~ semaName ~ `
        .pushsection .probes, \"aw\", \"progbits\"
        .weak ` ~ semaName ~ `
        .hidden ` ~semaName ~ `
        .balign 4
` ~ semaName ~ `:
        .zero 2
        .type ` ~ semaName ~ `, @object
        .size ` ~ semaName ~ `, 2
        .popsection
.endif
        .pushsection .note.stapsdt,\"\",\"note\"
        .balign 4
        .4byte 992f-991f, 994f-993f, 3  // length, type
991:
        .asciz \"stapsdt\"  // vendor string
992:
        .balign 4
993:
        .8byte 990b  // probe PC address
        .8byte _.stapsdt.base  // link-time sh_addr of base .stapsdt.base
        .8byte `~ semaName ~ `  // probe semaphore address
        .asciz \"` ~ provider ~ `\"  // provider name
        .asciz \"` ~ probe ~ `\"  // probe name
        .asciz \"` ~ spec ~ `\"
994:
        .balign 4
        .popsection
.ifndef _.stapsdt.base
        .pushsection .stapsdt.base, \"aGR\", \"progbits\", .stapsdt.base, comdat
        .weak _.stapsdt.base
        .hidden _.stapsdt.base
_.stapsdt.base:
        .space 1
        .size _.stapsdt.base, 1
        .popsection
        .endif", "` ~ cons ~ `"` ~ operands ~ `);
    }
}`;
}();

interface MyApp
{
    void start(int id);
    void tick();
}

void main()
{
    // ここのiを参照するのでfor文にする
    for (int i; ; i++)
    {      
        mixin(emitProbe!(MyApp.start, "i"));
        mixin(emitProbe!(MyApp.tick));
        Thread.sleep(500.msecs);
    }
}
