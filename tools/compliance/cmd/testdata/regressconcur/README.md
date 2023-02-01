## Start long walks followed by short walks

Detect concurrency error where "already started" treated as
"already finished".

### Testdata build graph structure:

A restricted licensed library sandwiched between a notice library and a notice
binary. The source-code for the libraries only needs to be shared if shipped
alongside the container with the binaries.

```dot
strict digraph {
	rankdir=LR;
	bin1 [label="bin/bin1.meta_lic\nproprietary"];
	bin2 [label="bin/bin2.meta_lic\nproprietary"];
	bin3 [label="bin/bin3.meta_lic\nproprietary"];
	bin4 [label="bin/bin4.meta_lic\nproprietary"];
	bin5 [label="bin/bin5.meta_lic\nproprietary"];
	bin6 [label="bin/bin6.meta_lic\nproprietary"];
	bin7 [label="bin/bin7.meta_lic\nproprietary"];
	bin8 [label="bin/bin8.meta_lic\nproprietary"];
	bin9 [label="bin/bin9.meta_lic\nproprietary"];
	container [label="container.zip.meta_lic\nnotice"];
	lib1 [label="lib/lib1.so.meta_lic\nnotice"];
	lib2 [label="lib/lib2.so.meta_lic\nnotice"];
	lib3 [label="lib/lib3.so.meta_lic\nnotice"];
	lib4 [label="lib/lib4.so.meta_lic\nnotice"];
	lib5 [label="lib/lib5.so.meta_lic\nnotice"];
	lib6 [label="lib/lib6.so.meta_lic\nnotice"];
	lib7 [label="lib/lib7.so.meta_lic\nnotice"];
	lib8 [label="lib/lib8.so.meta_lic\nnotice"];
	lib9 [label="lib/lib9.so.meta_lic\nrestricted"];
	container -> bin1 [label="static"];
	container -> bin2 [label="static"];
	container -> bin3 [label="static"];
	container -> bin4 [label="static"];
	container -> bin5 [label="static"];
	container -> bin6 [label="static"];
	container -> bin7 [label="static"];
	container -> bin8 [label="static"];
	container -> bin9 [label="static"];
	bin1 -> lib1 [label="static"];
	bin2 -> lib2 [label="static"];
	bin3 -> lib3 [label="static"];
	bin4 -> lib4 [label="static"];
	bin5 -> lib5 [label="static"];
	bin6 -> lib6 [label="static"];
	bin7 -> lib7 [label="static"];
	bin8 -> lib8 [label="static"];
	bin9 -> lib9 [label="static"];
	lib1 -> lib2 [label="static"];
	lib2 -> lib3 [label="static"];
	lib3 -> lib4 [label="static"];
	lib4 -> lib5 [label="static"];
	lib5 -> lib6 [label="static"];
	lib6 -> lib7 [label="static"];
	lib7 -> lib8 [label="static"];
	lib8 -> lib9 [label="static"];
	{rank=same; container}
}
```
