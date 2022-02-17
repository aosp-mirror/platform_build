## Test data

Each non-regression directory under testdata/ defines a similar build graph.
All have the same structure, but different versions of the graph have different
license metadata.

The regression* directories can have whatever structure is required for the
specific test case.

### Testdata build graph structure:

The structure is meant to simulate some common scenarios:

*   a `lib/` directory with some libraries
*   a `bin/` directory with some executables
*   one of the binaries, `bin3`, is a toolchain executable like a compiler
*   an `application` built with the `bin3` compiler and linking a couple libraries
*   a pure aggregation `continer.zip` that merely bundles files together, and
*   an apex file (more like an apk file) with some binaries and libraries.

The testdata starts with a `firstparty/` version containng only first-party
licenses, and each subsequent directory introduces more restrictive conditions:

*   `notice/` starts with `firstparty/` adds third-party notice conditions
*   `reciprocal/` starts with `notice/` and adds some reciprocal conditions
*   `restricted/` starts with `reciprocal/` and adds some restricted conditions
*   `proprietary/` starts with `restricted/` and add some privacy conditions

#### a `lib/` directory with some libraries

```dot
strict digraph {
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	libc [label="lib/libc.a.meta_lic"];
	libd [label="lib/libd.so.meta_lic"];
}
```

#### a `bin/` directory with some executables

strict digraph {
	rankdir=LR;
	bin1 [label="bin/bin1.meta_lic"];
	bin2 [label="bin/bin2.meta_lic"];
	bin3 [label="bin/bin3.meta_lic\ntoolchain"];
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	libc [label="lib/libc.a.meta_lic"];
	libd [label="lib/libd.so.meta_lic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	{rank=same; bin1 bin2 bin3}
}

#### an `application` built with the `bin3` compiler and linking a couple libraries

```dot
strict digraph {
	rankdir=LR;
	app [label="application.meta_lic"];
	bin3 [label="bin/bin3.meta_lic"];
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	{rank=same; app}
}
```

#### a pure aggregation `container.zip` that merely bundles files together

```dot
strict digraph {
	rankdir=LR;
	bin1 [label="bin/bin1.meta_lic"];
	bin2 [label="bin/bin2.meta_lic"];
	container [label="container.zip.meta_lic"];
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	libc [label="lib/libc.a.meta_lic"];
	libd [label="lib/libd.so.meta_lic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	{rank=same; container}
}
```

#### an apex file (more like an apk file) with some binaries and libraries

```dot
strict digraph {
	rankdir=LR;
	apex [label="highest.apex.meta_lic"];
	bin1 [label="bin/bin1.meta_lic"];
	bin2 [label="bin/bin2.meta_lic"];
	bin3 [label="bin/bin3.meta_lic"];
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	libc [label="lib/libc.a.meta_lic"];
	libd [label="lib/libd.so.meta_lic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; apex}
}
```

#### the whole build graph

```dot
strict digraph {
	rankdir=LR;
	apex [label="highest.apex.meta_lic"];
	app [label="application.meta_lic"];
	bin1 [label="bin/bin1.meta_lic"];
	bin2 [label="bin/bin2.meta_lic"];
	bin3 [label="bin/bin3.meta_lic"];
	container [label="container.zip.meta_lic"];
	liba [label="lib/liba.so.meta_lic"];
	libb [label="lib/libb.so.meta_lic"];
	libc [label="lib/libc.a.meta_lic"];
	libd [label="lib/libd.so.meta_lic"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```


### firstparty/ testdata starts with all first-party licensing

```dot
strict digraph {
	rankdir=LR;
	app [label="firstparty/application.meta_lic"];
	bin1 [label="firstparty/bin/bin1.meta_lic"];
	bin2 [label="firstparty/bin/bin2.meta_lic"];
	bin3 [label="firstparty/bin/bin3.meta_lic"];
	container [label="firstparty/container.zip.meta_lic"];
	apex [label="firstparty/highest.apex.meta_lic"];
	liba [label="firstparty/lib/liba.so.meta_lic"];
	libb [label="firstparty/lib/libb.so.meta_lic"];
	libc [label="firstparty/lib/libc.a.meta_lic"];
	lib [label="firstparty/lib/libd.so.meta_lic"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```

### notice/ testdata introduces third-party notice conditions

```dot
strict digraph {
	rankdir=LR;
	app [label="notice/application.meta_lic"];
	bin1 [label="notice/bin/bin1.meta_lic"];
	bin2 [label="notice/bin/bin2.meta_lic"];
	bin3 [label="notice/bin/bin3.meta_lic\nnotice"];
	container [label="notice/container.zip.meta_lic"];
	apex [label="notice/highest.apex.meta_lic"];
	liba [label="notice/lib/liba.so.meta_lic\nnotice"];
	libb [label="notice/lib/libb.so.meta_lic"];
	libc [label="notice/lib/libc.a.meta_lic\nnotice"];
	libd [label="notice/lib/libd.so.meta_lic\nnotice"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```

### reciprocal/ testdata introduces third-party reciprocal sharing conditions

```dot
strict digraph {
	rankdir=LR;
	app [label="reciprocal/application.meta_lic"];
	bin1 [label="reciprocal/bin/bin1.meta_lic"];
	bin2 [label="reciprocal/bin/bin2.meta_lic"];
	bin3 [label="reciprocal/bin/bin3.meta_lic\nnotice"];
	container [label="reciprocal/container.zip.meta_lic"];
	apex [label="reciprocal/highest.apex.meta_lic"];
	liba [label="reciprocal/lib/liba.so.meta_lic\nreciprocal"];
	libb [label="reciprocal/lib/libb.so.meta_lic"];
	libc [label="reciprocal/lib/libc.a.meta_lic\nreciprocal"];
	libd [label="reciprocal/lib/libd.so.meta_lic\nnotice"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```

### restricted/ testdata introduces restricted source sharing conditions

```dot
strict digraph {
	rankdir=LR;
	app [label="restricted/application.meta_lic"];
	bin1 [label="restricted/bin/bin1.meta_lic"];
	bin2 [label="restricted/bin/bin2.meta_lic"];
	bin3 [label="restricted/bin/bin3.meta_lic\nrestricted"];
	container [label="restricted/container.zip.meta_lic"];
	apex [label="restricted/highest.apex.meta_lic"];
	liba [label="restricted/lib/liba.so.meta_lic\nrestricted"];
	libb [label="restricted/lib/libb.so.meta_lic\nrestricted"];
	libc [label="restricted/lib/libc.a.meta_lic\nreciprocal"];
	libd [label="restricted/lib/libd.so.meta_lic\nnotice"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```

### proprietary/ testdata introduces privacy conditions

```dot
strict digraph {
	rankdir=LR;
	app [label="proprietary/application.meta_lic"];
	bin1 [label="proprietary/bin/bin1.meta_lic"];
	bin2 [label="proprietary/bin/bin2.meta_lic\nby_exception_only\nproprietary"];
	bin3 [label="proprietary/bin/bin3.meta_lic\nrestricted"];
	container [label="proprietary/container.zip.meta_lic"];
	apex [label="proprietary/highest.apex.meta_lic"];
	liba [label="proprietary/lib/liba.so.meta_lic\nby_exception_only\nproprietary"];
	libb [label="proprietary/lib/libb.so.meta_lic\nrestricted"];
	libc [label="proprietary/lib/libc.a.meta_lic\nby_exception_only\nproprietary"];
	libd [label="proprietary/lib/libd.so.meta_lic\nnotice"];
	app -> bin3 [label="toolchain"];
	app -> liba [label="static"];
	app -> libb [label="dynamic"];
	bin1 -> liba [label="static"];
	bin1 -> libc [label="static"];
	bin2 -> libb [label="dynamic"];
	bin2 -> libd [label="dynamic"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> liba [label="static"];
	container -> libb [label="static"];
	apex -> bin1 [label="static"];
	apex -> bin2 [label="static"];
	apex -> liba [label="static"];
	apex -> libb [label="static"];
	{rank=same; app container apex}
}
```
