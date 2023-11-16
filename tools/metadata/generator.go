package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strings"
	"sync"

	"android/soong/testing/test_spec_proto"
	"google.golang.org/protobuf/proto"
)

type keyToLocksMap struct {
	locks sync.Map
}

func (kl *keyToLocksMap) GetLockForKey(key string) *sync.Mutex {
	mutex, _ := kl.locks.LoadOrStore(key, &sync.Mutex{})
	return mutex.(*sync.Mutex)
}

func getSortedKeys(syncMap *sync.Map) []string {
	var allKeys []string
	syncMap.Range(
		func(key, _ interface{}) bool {
			allKeys = append(allKeys, key.(string))
			return true
		},
	)

	sort.Strings(allKeys)
	return allKeys
}

func writeOutput(
	outputFile string,
	allMetadata []*test_spec_proto.TestSpec_OwnershipMetadata,
) {
	testSpec := &test_spec_proto.TestSpec{
		OwnershipMetadataList: allMetadata,
	}
	data, err := proto.Marshal(testSpec)
	if err != nil {
		log.Fatal(err)
	}
	file, err := os.Create(outputFile)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	_, err = file.Write(data)
	if err != nil {
		log.Fatal(err)
	}
}

func readFileToString(filePath string) string {
	file, err := os.Open(filePath)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		log.Fatal(err)
	}
	return string(data)
}

func writeNewlineToOutputFile(outputFile string) {
	file, err := os.Create(outputFile)
	data := "\n"
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	_, err = file.Write([]byte(data))
	if err != nil {
		log.Fatal(err)
	}
}

func processTestSpecProtobuf(
	filePath string, ownershipMetadataMap *sync.Map, keyLocks *keyToLocksMap,
	errCh chan error, wg *sync.WaitGroup,
) {
	defer wg.Done()

	fileContent := strings.TrimRight(readFileToString(filePath), "\n")
	testData := test_spec_proto.TestSpec{}
	err := proto.Unmarshal([]byte(fileContent), &testData)
	if err != nil {
		errCh <- err
		return
	}

	ownershipMetadata := testData.GetOwnershipMetadataList()
	for _, metadata := range ownershipMetadata {
		key := metadata.GetTargetName()
		lock := keyLocks.GetLockForKey(key)
		lock.Lock()

		value, loaded := ownershipMetadataMap.LoadOrStore(
			key, []*test_spec_proto.TestSpec_OwnershipMetadata{metadata},
		)
		if loaded {
			existingMetadata := value.([]*test_spec_proto.TestSpec_OwnershipMetadata)
			isDuplicate := false
			for _, existing := range existingMetadata {
				if metadata.GetTrendyTeamId() != existing.GetTrendyTeamId() {
					errCh <- fmt.Errorf(
						"Conflicting trendy team IDs found for %s at:\n%s with teamId"+
							": %s,\n%s with teamId: %s",
						key,
						metadata.GetPath(), metadata.GetTrendyTeamId(), existing.GetPath(),
						existing.GetTrendyTeamId(),
					)

					lock.Unlock()
					return
				}
				if metadata.GetTrendyTeamId() == existing.GetTrendyTeamId() && metadata.GetPath() == existing.GetPath() {
					isDuplicate = true
					break
				}
			}
			if !isDuplicate {
				existingMetadata = append(existingMetadata, metadata)
				ownershipMetadataMap.Store(key, existingMetadata)
			}
		}

		lock.Unlock()
	}
}

func main() {
	inputFile := flag.String("inputFile", "", "Input file path")
	outputFile := flag.String("outputFile", "", "Output file path")
	rule := flag.String("rule", "", "Metadata rule (Hint: test_spec or code_metadata)")
	flag.Parse()

	if *inputFile == "" || *outputFile == "" || *rule == "" {
		fmt.Println("Usage: metadata -rule <rule> -inputFile <input file path> -outputFile <output file path>")
		os.Exit(1)
	}

	inputFileData := strings.TrimRight(readFileToString(*inputFile), "\n")
	filePaths := strings.Split(inputFileData, "\n")
	if len(filePaths) == 1 && filePaths[0] == "" {
		writeNewlineToOutputFile(*outputFile)
		return
	}
	ownershipMetadataMap := &sync.Map{}
	keyLocks := &keyToLocksMap{}
	errCh := make(chan error, len(filePaths))
	var wg sync.WaitGroup

	switch *rule {
	case "test_spec":
		for _, filePath := range filePaths {
			wg.Add(1)
			go processTestSpecProtobuf(filePath, ownershipMetadataMap, keyLocks, errCh, &wg)
		}

		wg.Wait()
		close(errCh)

		for err := range errCh {
			log.Fatal(err)
		}

		allKeys := getSortedKeys(ownershipMetadataMap)
		var allMetadata []*test_spec_proto.TestSpec_OwnershipMetadata

		for _, key := range allKeys {
			value, _ := ownershipMetadataMap.Load(key)
			metadataList := value.([]*test_spec_proto.TestSpec_OwnershipMetadata)
			allMetadata = append(allMetadata, metadataList...)
		}

		writeOutput(*outputFile, allMetadata)
		break
	case "code_metadata":
	default:
		log.Fatalf("No specific processing implemented for rule '%s'.\n", *rule)
	}
}
