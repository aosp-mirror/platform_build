package main

import (
	"fmt"
	"io/ioutil"
	"os/exec"
	"strings"
	"testing"
)

func TestMetadata(t *testing.T) {
	cmd := exec.Command(
		"metadata", "-rule", "test_spec", "-inputFile", "./inputFiles.txt", "-outputFile",
		"./generatedOutputFile.txt",
	)
	stderr, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Error running metadata command: %s. Error: %v", stderr, err)
	}

	// Read the contents of the expected output file
	expectedOutput, err := ioutil.ReadFile("./expectedOutputFile.txt")
	if err != nil {
		t.Fatalf("Error reading expected output file: %s", err)
	}

	// Read the contents of the generated output file
	generatedOutput, err := ioutil.ReadFile("./generatedOutputFile.txt")
	if err != nil {
		t.Fatalf("Error reading generated output file: %s", err)
	}

	fmt.Println()

	// Compare the contents
	if string(expectedOutput) != string(generatedOutput) {
		t.Errorf("Generated file contents do not match the expected output")
	}
}

func TestMetadataNegativeCase(t *testing.T) {
	cmd := exec.Command(
		"metadata", "-rule", "test_spec", "-inputFile", "./inputFilesNegativeCase.txt", "-outputFile",
		"./generatedOutputFileNegativeCase.txt",
	)
	stderr, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf(
			"Expected an error, but the metadata command executed successfully. Output: %s",
			stderr,
		)
	}

	expectedError := "Conflicting trendy team IDs found for java-test-module" +
		"-name-one at:\nAndroid.bp with teamId: 12346," +
		"\nAndroid.bp with teamId: 12345"
	if !strings.Contains(
		strings.TrimSpace(string(stderr)), strings.TrimSpace(expectedError),
	) {
		t.Errorf(
			"Unexpected error message. Expected to contain: %s, Got: %s",
			expectedError, stderr,
		)
	}
}
