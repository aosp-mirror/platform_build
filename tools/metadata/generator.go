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

	"android/soong/testing/code_metadata_internal_proto"
	"android/soong/testing/code_metadata_proto"
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

// Define a struct to hold the combination of team ID and multi-ownership flag for validation
type sourceFileAttributes struct {
	TeamID         string
	MultiOwnership bool
	Path           string
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

// writeProtoToFile marshals a protobuf message and writes it to a file
func writeProtoToFile(outputFile string, message proto.Message) {
	data, err := proto.Marshal(message)
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

func writeEmptyOutputProto(outputFile string, metadataRule string) {
	file, err := os.Create(outputFile)
	if err != nil {
		log.Fatal(err)
	}
	var message proto.Message
	if metadataRule == "test_spec" {
		message = &test_spec_proto.TestSpec{}
	} else if metadataRule == "code_metadata" {
		message = &code_metadata_proto.CodeMetadata{}
	}
	data, err := proto.Marshal(message)
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

// processCodeMetadataProtobuf processes CodeMetadata protobuf files
func processCodeMetadataProtobuf(
	filePath string, ownershipMetadataMap *sync.Map, sourceFileMetadataMap *sync.Map, keyLocks *keyToLocksMap,
	errCh chan error, wg *sync.WaitGroup,
) {
	defer wg.Done()

	fileContent := strings.TrimRight(readFileToString(filePath), "\n")
	internalCodeData := code_metadata_internal_proto.CodeMetadataInternal{}
	err := proto.Unmarshal([]byte(fileContent), &internalCodeData)
	if err != nil {
		errCh <- err
		return
	}

	// Process each TargetOwnership entry
	for _, internalMetadata := range internalCodeData.GetTargetOwnershipList() {
		key := internalMetadata.GetTargetName()
		lock := keyLocks.GetLockForKey(key)
		lock.Lock()

		for _, srcFile := range internalMetadata.GetSourceFiles() {
			srcFileKey := srcFile
			srcFileLock := keyLocks.GetLockForKey(srcFileKey)
			srcFileLock.Lock()
			attributes := sourceFileAttributes{
				TeamID:         internalMetadata.GetTrendyTeamId(),
				MultiOwnership: internalMetadata.GetMultiOwnership(),
				Path:           internalMetadata.GetPath(),
			}

			existingAttributes, exists := sourceFileMetadataMap.Load(srcFileKey)
			if exists {
				existing := existingAttributes.(sourceFileAttributes)
				if attributes.TeamID != existing.TeamID && (!attributes.MultiOwnership || !existing.MultiOwnership) {
					errCh <- fmt.Errorf(
						"Conflict found for source file %s covered at %s with team ID: %s. Existing team ID: %s and path: %s."+
							" If multi-ownership is required, multiOwnership should be set to true in all test_spec modules using this target. "+
							"Multiple-ownership in general is discouraged though as it make infrastructure around android relying on this information pick up a random value when it needs only one.",
						srcFile, internalMetadata.GetPath(), attributes.TeamID, existing.TeamID, existing.Path,
					)
					srcFileLock.Unlock()
					lock.Unlock()
					return
				}
			} else {
				// Store the metadata if no conflict
				sourceFileMetadataMap.Store(srcFileKey, attributes)
			}
			srcFileLock.Unlock()
		}

		value, loaded := ownershipMetadataMap.LoadOrStore(
			key, []*code_metadata_internal_proto.CodeMetadataInternal_TargetOwnership{internalMetadata},
		)
		if loaded {
			existingMetadata := value.([]*code_metadata_internal_proto.CodeMetadataInternal_TargetOwnership)
			isDuplicate := false
			for _, existing := range existingMetadata {
				if internalMetadata.GetTrendyTeamId() == existing.GetTrendyTeamId() && internalMetadata.GetPath() == existing.GetPath() {
					isDuplicate = true
					break
				}
			}
			if !isDuplicate {
				existingMetadata = append(existingMetadata, internalMetadata)
				ownershipMetadataMap.Store(key, existingMetadata)
			}
		}

		lock.Unlock()
	}
}

func main() {
	inputFile := flag.String("inputFile", "", "Input file path")
	outputFile := flag.String("outputFile", "", "Output file path")
	rule := flag.String(
		"rule", "", "Metadata rule (Hint: test_spec or code_metadata)",
	)
	flag.Parse()

	if *inputFile == "" || *outputFile == "" || *rule == "" {
		fmt.Println("Usage: metadata -rule <rule> -inputFile <input file path> -outputFile <output file path>")
		os.Exit(1)
	}

	inputFileData := strings.TrimRight(readFileToString(*inputFile), "\n")
	filePaths := strings.Split(inputFileData, " ")
	if len(filePaths) == 1 && filePaths[0] == "" {
		writeEmptyOutputProto(*outputFile, *rule)
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
			go processTestSpecProtobuf(
				filePath, ownershipMetadataMap, keyLocks, errCh, &wg,
			)
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

		testSpec := &test_spec_proto.TestSpec{
			OwnershipMetadataList: allMetadata,
		}
		writeProtoToFile(*outputFile, testSpec)
		break
	case "code_metadata":
		sourceFileMetadataMap := &sync.Map{}
		for _, filePath := range filePaths {
			wg.Add(1)
			go processCodeMetadataProtobuf(
				filePath, ownershipMetadataMap, sourceFileMetadataMap, keyLocks, errCh, &wg,
			)
		}

		wg.Wait()
		close(errCh)

		for err := range errCh {
			log.Fatal(err)
		}

		sortedKeys := getSortedKeys(ownershipMetadataMap)
		allMetadata := make([]*code_metadata_proto.CodeMetadata_TargetOwnership, 0)
		for _, key := range sortedKeys {
			value, _ := ownershipMetadataMap.Load(key)
			metadata := value.([]*code_metadata_internal_proto.CodeMetadataInternal_TargetOwnership)
			for _, m := range metadata {
				targetName := m.GetTargetName()
				path := m.GetPath()
				trendyTeamId := m.GetTrendyTeamId()

				allMetadata = append(allMetadata, &code_metadata_proto.CodeMetadata_TargetOwnership{
					TargetName:   &targetName,
					Path:         &path,
					TrendyTeamId: &trendyTeamId,
					SourceFiles:  m.GetSourceFiles(),
				})
			}
		}

		finalMetadata := &code_metadata_proto.CodeMetadata{
			TargetOwnershipList: allMetadata,
		}
		writeProtoToFile(*outputFile, finalMetadata)
		break
	default:
		log.Fatalf("No specific processing implemented for rule '%s'.\n", *rule)
	}
}
