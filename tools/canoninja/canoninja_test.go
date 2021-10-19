package canoninja

import (
	"bytes"
	"testing"
)

func TestGenerate(t *testing.T) {
	tests := []struct {
		name     string
		in       []byte
		wantSink string
		wantErr  bool
	}{
		{
			name: "1",
			in: []byte(`
rule rule1
  abcd
rule rule2
  abcd
build x: rule1
`),
			wantSink: `
rule R9c97aba7f61994be6862f5ea9a62d26130c7f48b
  abcd
rule R9c97aba7f61994be6862f5ea9a62d26130c7f48b
  abcd
build x: R9c97aba7f61994be6862f5ea9a62d26130c7f48b
`,
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sink := &bytes.Buffer{}
			err := Generate("<file>", tt.in, sink)
			if (err != nil) != tt.wantErr {
				t.Errorf("Generate() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if gotSink := sink.String(); gotSink != tt.wantSink {
				t.Errorf("Generate() gotSink = %v, want %v", gotSink, tt.wantSink)
			}
		})
	}
}
