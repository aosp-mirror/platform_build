## Shipped versus non-shipped libraries with restricted license

### Testdata build graph structure:

A restricted licensed library sandwiched between a notice library and a notice
binary. The source-code for the libraries only needs to be shared if shipped
alongside the container with the binaries.

```dot
strict digraph {
	rankdir=LR;
	bin1 [label="bin/bin1.meta_lic\nnotice"];
	bin2 [label="bin/bin2.meta_lic\nnotice"];
	bin3 [label="bin/bin3.meta_lic\nnotice"];
	container [label="container.zip.meta_lic\nnotice"];
	libapache [label="lib/libapache.so.meta_lic\nnotice"];
	libcxx [label="lib/libc++.so.meta_lic\nnotice"];
	libgpl [label="lib/libgpl.so.meta_lic\nrestricted"];
	container -> bin1[label="static"];
	container -> bin2 [label="static"];
	container -> bin3 [label="static"];
	bin1 -> libcxx [label="dynamic"];
	bin2 -> libapache [label="dynamic"];
	bin2 -> libcxx [label="dynamic"];
	bin3 -> libapache [label="dynamic"];
	bin3 -> libcxx [label="dynamic"];
	bin3 -> libgpl [label="dynamic"];
	libapache -> libcxx [label="dynamic"];
	libgpl -> libcxx [label="dynamic"];
	{rank=same; container}
}
```
