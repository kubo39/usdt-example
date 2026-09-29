# usdt example

## 試す

```console
make run
```

別ターミナル(同じディレクトリ階層)で:

```console
sudo bpftrace -e 'usdt:./app:MyApp:start { printf("id=%d\n", arg0); }'
Attaching 1 probe...
id=8
id=9
id=10
id=11
id=12
^C
```

## 参照

- [SystemTap: UserSpaceProbeImplementation](https://sourceware.org/systemtap/wiki/UserSpaceProbeImplementation)
