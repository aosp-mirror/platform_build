#include <stdio.h>
//#include <common.h>
#include <debug.h>
#include <libelf.h>
#include <libebl.h>
#include <libebl_arm.h>
#include <elf.h>
#include <gelf.h>
#include <string.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
#include <prelink_info.h>
#endif

#include <elfcopy.h>

void clone_elf(Elf *elf, Elf *newelf,
               const char *elf_name,
               const char *newelf_name,
               bool *sym_filter, int num_symbols,
               int shady
#ifdef SUPPORT_ANDROID_PRELINK_TAGS
               , int *prelinked,
               int *elf_little,
               long *prelink_addr
#endif
               , bool rebuild_shstrtab,
               bool strip_debug,
               bool dry_run)
{
	GElf_Ehdr ehdr_mem, *ehdr; /* store ELF header of original library */
	size_t shstrndx; /* section-strings-section index */
	size_t shnum; /* number of sections in the original file */
	/* string table for section headers in new file */
	struct Ebl_Strtab *shst = NULL;
    int dynamic_idx = -1; /* index in shdr_info[] of .dynamic section */
    int dynsym_idx = -1; /* index in shdr_info[] of dynamic symbol table
                            section */

    int cnt;	  /* general-purpose counter */
    /* This flag is true when at least one section is dropped or when the
       relative order of sections has changed, so that section indices in
       the resulting file will be different from those in the original. */
    bool sections_dropped_or_rearranged;
	Elf_Scn *scn; /* general-purpose section */
	size_t idx;	  /* general-purporse section index */

	shdr_info_t *shdr_info = NULL;
    int shdr_info_len = 0;
    GElf_Phdr *phdr_info = NULL;

	/* Get the information from the old file. */
	ehdr = gelf_getehdr (elf, &ehdr_mem);
	FAILIF_LIBELF(NULL == ehdr, gelf_getehdr);

	/* Create new program header for the elf file */
	FAILIF(gelf_newehdr (newelf, gelf_getclass (elf)) == 0 ||
		   (ehdr->e_type != ET_REL && gelf_newphdr (newelf,
													ehdr->e_phnum) == 0),
		   "Cannot create new file: %s", elf_errmsg (-1));

#ifdef SUPPORT_ANDROID_PRELINK_TAGS
    ASSERT(prelinked);
    ASSERT(prelink_addr);
    ASSERT(elf_little);
    *elf_little = (ehdr->e_ident[EI_DATA] == ELFDATA2LSB);
    *prelinked = check_prelinked(elf_name, *elf_little, prelink_addr);
#endif

    INFO("\n\nCALCULATING MODIFICATIONS\n\n");

	/* Copy out the old program header: notice that if the ELF file does not
	   have a program header, this loop won't execute.
	*/
	INFO("Copying ELF program header...\n");
    phdr_info = (GElf_Phdr *)CALLOC(ehdr->e_phnum, sizeof(GElf_Phdr));
	for (cnt = 0; cnt < ehdr->e_phnum; ++cnt) {
		INFO("\tRetrieving entry %d\n", cnt);
		FAILIF_LIBELF(NULL == gelf_getphdr(elf, cnt, phdr_info + cnt),
                      gelf_getphdr);
        /* -- we update the header at the end
        FAILIF_LIBELF(gelf_update_phdr (newelf, cnt, phdr_info + cnt) == 0,
                      gelf_update_phdr);
        */
	}

    /* Get the section-header strings section.  This section contains the
	   strings used to name the other sections. */
	FAILIF_LIBELF(elf_getshstrndx(elf, &shstrndx) < 0, elf_getshstrndx);

	/* Get the number of sections. */
	FAILIF_LIBELF(elf_getshnum (elf, &shnum) < 0, elf_getshnum);
	INFO("Original ELF file has %d sections.\n", shnum);

	/* Allocate the section-header-info buffer.  We allocate one more entry
       for the section-strings section because we regenerate that one and
       place it at the very end of the file.  Note that just because we create
       an extra entry in the shdr_info array, it does not mean that we create
       one more section the header.  We just mark the old section for removal
       and create one as the last section.
    */
	INFO("Allocating section-header info structure (%d) bytes...\n",
		 shnum*sizeof (shdr_info_t));
    shdr_info_len = rebuild_shstrtab ? shnum + 1 : shnum;
	shdr_info = (shdr_info_t *)CALLOC(shdr_info_len, sizeof (shdr_info_t));

	/* Iterate over all the sections and initialize the internal section-info
	   array...
	*/
	INFO("Initializing section-header info structure...\n");
	/* Gather information about the sections in this file. */
	scn = NULL;
	cnt = 1;
	while ((scn = elf_nextscn (elf, scn)) != NULL) {
		ASSERT(elf_ndxscn(scn) == cnt);
		shdr_info[cnt].scn = scn;
		FAILIF_LIBELF(NULL == gelf_getshdr(scn, &shdr_info[cnt].shdr),
					  gelf_getshdr);

		/* Get the name of the section. */
		shdr_info[cnt].name = elf_strptr (elf, shstrndx,
										  shdr_info[cnt].shdr.sh_name);

		INFO("\tname: %s\n", shdr_info[cnt].name);
		FAILIF(shdr_info[cnt].name == NULL,
			   "Malformed file: section %d name is null\n",
			   cnt);

		/* Mark them as present but not yet investigated.  By "investigating"
		   sections, we mean that we check to see if by stripping other
		   sections, the sections under investigation will be compromised.  For
		   example, if we are removing a section of code, then we want to make
		   sure that the symbol table does not contain symbols that refer to
		   this code, so we investigate the symbol table.  If we do find such
		   symbols, we will not strip the code section.
		*/
		shdr_info[cnt].idx = 1;

		/* Remember the shdr.sh_link value.  We need to remember this value
		   for those sections that refer to other sections.  For example,
		   we need to remember it for relocation-entry sections, because if
		   we modify the symbol table that a relocation-entry section is
		   relative to, then we need to patch the relocation section.  By the
		   time we get to deciding whether we need to patch the relocation
		   section, we will have overwritten its header's sh_link field with
		   a new value.
		*/
		shdr_info[cnt].old_shdr = shdr_info[cnt].shdr;
        INFO("\t\toriginal sh_link: %08d\n", shdr_info[cnt].old_shdr.sh_link);
        INFO("\t\toriginal sh_addr: %lld\n", shdr_info[cnt].old_shdr.sh_addr);
        INFO("\t\toriginal sh_offset: %lld\n",
             shdr_info[cnt].old_shdr.sh_offset);
        INFO("\t\toriginal sh_size: %lld\n", shdr_info[cnt].old_shdr.sh_size);

        if (shdr_info[cnt].shdr.sh_type == SHT_DYNAMIC) {
            INFO("\t\tthis is the SHT_DYNAMIC section [%s] at index %d\n",
                 shdr_info[cnt].name,
                 cnt);
            dynamic_idx = cnt;
        }
        else if (shdr_info[cnt].shdr.sh_type == SHT_DYNSYM) {
            INFO("\t\tthis is the SHT_DYNSYM section [%s] at index %d\n",
                 shdr_info[cnt].name,
                 cnt);
            dynsym_idx = cnt;
        }

		FAILIF(shdr_info[cnt].shdr.sh_type == SHT_SYMTAB_SHNDX,
			   "Cannot handle sh_type SHT_SYMTAB_SHNDX!\n");
		FAILIF(shdr_info[cnt].shdr.sh_type == SHT_GROUP,
			   "Cannot handle sh_type SHT_GROUP!\n");
		FAILIF(shdr_info[cnt].shdr.sh_type == SHT_GNU_versym,
			   "Cannot handle sh_type SHT_GNU_versym!\n");

		/* Increment the counter. */
		++cnt;
	} /* while */

	/* Get the EBL handling. */
	Ebl *ebl = ebl_openbackend (elf);
	FAILIF_LIBELF(NULL == ebl, ebl_openbackend);
    FAILIF_LIBELF(0 != arm_init(elf, ehdr->e_machine, ebl, sizeof(Ebl)),
                  arm_init);

    if (strip_debug) {

      /* This will actually strip more than just sections.  It will strip
         anything not essential to running the image.
      */

      INFO("Finding debug sections to strip.\n");

      /* Now determine which sections can go away.  The general rule is that
         all sections which are not used at runtime are stripped out.  But
         there are a few exceptions:

         - special sections named ".comment" and ".note" are kept
         - OS or architecture specific sections are kept since we might not
		 know how to handle them
         - if a section is referred to from a section which is not removed
		 in the sh_link or sh_info element it cannot be removed either
      */
      for (cnt = 1; cnt < shnum; ++cnt) {
		/* Check whether the section can be removed.  */
		if (SECTION_STRIP_P (ebl, elf, ehdr, &shdr_info[cnt].shdr,
							 shdr_info[cnt].name,
							 1,	 /* remove .comment sections */
							 1	 /* remove all debug sections */) ||
            /* The macro above is broken--check for .comment explicitly */
            !strcmp(".comment", shdr_info[cnt].name)
#ifdef ARM_SPECIFIC_HACKS
            ||
            /* We ignore this section, that's why we can remove it. */
            !strcmp(".stack", shdr_info[cnt].name)
#endif
            )
        {
          /* For now assume this section will be removed.  */
          INFO("Section [%s] will be stripped from image.\n",
               shdr_info[cnt].name);
          shdr_info[cnt].idx = 0;
		}
#ifdef STRIP_STATIC_SYMBOLS
		else if (shdr_info[cnt].shdr.sh_type == SHT_SYMTAB) {
          /* Mark the static symbol table for removal */
          INFO("Section [%s] (static symbol table) will be stripped from image.\n",
               shdr_info[cnt].name);
          shdr_info[cnt].idx = 0;
          if (shdr_info[shdr_info[cnt].shdr.sh_link].shdr.sh_type ==
              SHT_STRTAB)
          {
            /* Mark the symbol table's string table for removal. */
            INFO("Section [%s] (static symbol-string table) will be stripped from image.\n",
                 shdr_info[cnt].name);
            shdr_info[shdr_info[cnt].shdr.sh_link].idx = 0;
          }
          else {
            ERROR("Expecting the sh_link field of a symbol table to point to"
                  " associated symbol-strings table!  This is not mandated by"
                  " the standard, but is a common practice and the only way "
                  " to know for sure which strings table corresponds to which"
                  " symbol table!\n");
          }
		}
#endif
      }

      /* Mark the SHT_NULL section as handled. */
      shdr_info[0].idx = 2;

      /* Handle exceptions: section groups and cross-references.  We might have
         to repeat this a few times since the resetting of the flag might
         propagate.
      */
      int exceptions_pass = 0;
      bool changes;
      do {
        changes = false;
		INFO("\nHandling exceptions, pass %d\n\n", exceptions_pass++);
		for (cnt = 1; cnt < shnum; ++cnt) {
          if (shdr_info[cnt].idx == 0) {
            /* If a relocation section is marked as being removed but the
               section it is relocating is not, then do not remove the
               relocation section.
            */
            if ((shdr_info[cnt].shdr.sh_type == SHT_REL
                 || shdr_info[cnt].shdr.sh_type == SHT_RELA)
                && shdr_info[shdr_info[cnt].shdr.sh_info].idx != 0) {
              PRINT("\tSection [%s] will not be removed because the "
                    "section it is relocating (%s) stays.\n",
                    shdr_info[cnt].name,
                    shdr_info[shdr_info[cnt].shdr.sh_info].name);
            }
          }
          if (shdr_info[cnt].idx == 1) {
            INFO("Processing section [%s]...\n", shdr_info[cnt].name);

            /* The content of symbol tables we don't remove must not
               reference any section which we do remove.  Otherwise
               we cannot remove the referred section.
            */
            if (shdr_info[cnt].shdr.sh_type == SHT_DYNSYM ||
                shdr_info[cnt].shdr.sh_type == SHT_SYMTAB)
            {
              Elf_Data *symdata;
              size_t elsize;

              INFO("\tSection [%s] is a symbol table that's not being"
                   " removed.\n\tChecking to make sure that no symbols"
                   " refer to sections that are being removed.\n",
                   shdr_info[cnt].name);

              /* Make sure the data is loaded.  */
              symdata = elf_getdata (shdr_info[cnt].scn, NULL);
              FAILIF_LIBELF(NULL == symdata, elf_getdata);

              /* Go through all symbols and make sure the section they
                 reference is not removed.  */
              elsize = gelf_fsize (elf, ELF_T_SYM, 1, ehdr->e_version);

              /* Check the length of the dynamic-symbol filter. */
              FAILIF(sym_filter != NULL &&
                     num_symbols != symdata->d_size / elsize,
                     "Length of dynsym filter (%d) must equal the number"
                     " of dynamic symbols (%d)!\n",
                     num_symbols,
                     symdata->d_size / elsize);

              size_t inner;
              for (inner = 0;
                   inner < symdata->d_size / elsize;
                   ++inner)
              {
                GElf_Sym sym_mem;
                GElf_Sym *sym;
                size_t scnidx;

                sym = gelf_getsymshndx (symdata, NULL,
                                        inner, &sym_mem, NULL);
                FAILIF_LIBELF(sym == NULL, gelf_getsymshndx);

                scnidx = sym->st_shndx;
                FAILIF(scnidx == SHN_XINDEX,
                       "Can't handle SHN_XINDEX!\n");
                if (scnidx == SHN_UNDEF ||
                    scnidx >= shnum ||
                    (scnidx >= SHN_LORESERVE &&
                     scnidx <= SHN_HIRESERVE) ||
                    GELF_ST_TYPE (sym->st_info) == STT_SECTION)
                {
                  continue;
                }

                /* If the symbol is going to be thrown and it is a
                   global or weak symbol that is defined (not imported),
                   then continue.  Since the symbol is going away, we
                   do not care  whether it refers to a section that is
                   also going away.
                */
                if (sym_filter && !sym_filter[inner])
                {
                  bool global_or_weak =
                      ELF32_ST_BIND(sym->st_info) == STB_GLOBAL ||
                      ELF32_ST_BIND(sym->st_info) == STB_WEAK;
                  if (!global_or_weak && sym->st_shndx != SHN_UNDEF)
                    continue;
                }

                /* -- far too much output
                   INFO("\t\t\tSymbol [%s] (%d)\n",
                   elf_strptr(elf,
                   shdr_info[cnt].shdr.sh_link,
                   sym->st_name),
                   shdr_info[cnt].shdr.sh_info);
                */

                if (shdr_info[scnidx].idx == 0)
                {
                  PRINT("\t\t\tSymbol [%s] refers to section [%s], "
                        "which is being removed.  Will keep that "
                        "section.\n",
                        elf_strptr(elf,
                                   shdr_info[cnt].shdr.sh_link,
                                   sym->st_name),
                        shdr_info[scnidx].name);
                  /* Mark this section as used.  */
                  shdr_info[scnidx].idx = 1;
                  changes |= scnidx < cnt;
                }
              } /* for each symbol */
            } /* section type is SHT_DYNSYM or SHT_SYMTAB */
            /* Cross referencing happens:
			   - for the cases the ELF specification says.  That are
			   + SHT_DYNAMIC in sh_link to string table
			   + SHT_HASH in sh_link to symbol table
			   + SHT_REL and SHT_RELA in sh_link to symbol table
			   + SHT_SYMTAB and SHT_DYNSYM in sh_link to string table
			   + SHT_GROUP in sh_link to symbol table
			   + SHT_SYMTAB_SHNDX in sh_link to symbol table
			   Other (OS or architecture-specific) sections might as
			   well use this field so we process it unconditionally.
			   - references inside section groups
			   - specially marked references in sh_info if the SHF_INFO_LINK
			   flag is set
            */

            if (shdr_info[shdr_info[cnt].shdr.sh_link].idx == 0) {
              shdr_info[shdr_info[cnt].shdr.sh_link].idx = 1;
              changes |= shdr_info[cnt].shdr.sh_link < cnt;
            }

            /* Handle references through sh_info.  */
            if (SH_INFO_LINK_P (&shdr_info[cnt].shdr) &&
                shdr_info[shdr_info[cnt].shdr.sh_info].idx == 0) {
              PRINT("\tSection [%s] links to section [%s], which was "
                    "marked for removal--it will not be removed.\n",
                    shdr_info[cnt].name,
                    shdr_info[shdr_info[cnt].shdr.sh_info].name);

              shdr_info[shdr_info[cnt].shdr.sh_info].idx = 1;
              changes |= shdr_info[cnt].shdr.sh_info < cnt;
            }

            /* Mark the section as investigated.  */
            shdr_info[cnt].idx = 2;
          } /* if (shdr_info[cnt].idx == 1) */
		} /* for (cnt = 1; cnt < shnum; ++cnt) */
      } while (changes);
    }
    else {
      INFO("Not stripping sections.\n");
      /* Mark the SHT_NULL section as handled. */
      shdr_info[0].idx = 2;
    }

	/* Mark the section header string table as unused, we will create
	   a new one as the very last section in the new ELF file.
	*/
	shdr_info[shstrndx].idx = rebuild_shstrtab ? 0 : 2;

	/* We need a string table for the section headers. */
	FAILIF_LIBELF((shst = ebl_strtabinit (1	/* null-terminated */)) == NULL,
				  ebl_strtabinit);

	/* Assign new section numbers. */
	INFO("Creating new sections...\n");
	//shdr_info[0].idx = 0;
	for (cnt = idx = 1; cnt < shnum; ++cnt) {
		if (shdr_info[cnt].idx > 0) {
			shdr_info[cnt].idx = idx++;

			/* Create a new section. */
			FAILIF_LIBELF((shdr_info[cnt].newscn =
						   elf_newscn(newelf)) == NULL, elf_newscn);
			ASSERT(elf_ndxscn (shdr_info[cnt].newscn) == shdr_info[cnt].idx);

			/* Add this name to the section header string table. */
			shdr_info[cnt].se = ebl_strtabadd (shst, shdr_info[cnt].name, 0);

			INFO("\tsection [%s]  (old offset %lld, old size %lld) will have index %d "
				 "(was %d).\n",
				 shdr_info[cnt].name,
				 shdr_info[cnt].old_shdr.sh_offset,
				 shdr_info[cnt].old_shdr.sh_size,
				 shdr_info[cnt].idx,
				 elf_ndxscn(shdr_info[cnt].scn));
		} else {
			INFO("\tIgnoring section [%s] (offset %lld, size %lld, index %d), "
				 "it will be discarded.\n",
				 shdr_info[cnt].name,
				 shdr_info[cnt].shdr.sh_offset,
				 shdr_info[cnt].shdr.sh_size,
				 elf_ndxscn(shdr_info[cnt].scn));
		}
	} /* for */

    sections_dropped_or_rearranged = idx != cnt;

    Elf_Data *shstrtab_data = NULL;

#if 0
    /* Fail if sections are being dropped or rearranged (except for moving shstrtab) or the
       symbol filter is not empty, AND the file is an executable.
    */
    FAILIF(((idx != cnt && !(cnt - idx == 1 && rebuild_shstrtab)) || sym_filter != NULL) &&
           ehdr->e_type != ET_DYN,
           "You may not rearrange sections or strip symbols on an executable file!\n");
#endif

    INFO("\n\nADJUSTING ELF FILE\n\n");

    adjust_elf(elf, elf_name,
               newelf, newelf_name,
               ebl,
               ehdr, /* store ELF header of original library */
               sym_filter, num_symbols,
               shdr_info, shdr_info_len,
               phdr_info,
               idx, /* highest_scn_num */
               shnum,
               shstrndx,
               shst,
               sections_dropped_or_rearranged,
               dynamic_idx, /* index in shdr_info[] of .dynamic section */
               dynsym_idx, /* index in shdr_info[] of dynamic symbol table */
               shady,
               &shstrtab_data,
               ehdr->e_type == ET_DYN, /* adjust section ofsets only when the file is a shared library */
               rebuild_shstrtab);

    /* We have everything from the old file. */
	FAILIF_LIBELF(elf_cntl(elf, ELF_C_FDDONE) != 0, elf_cntl);

	/* The ELF library better follows our layout when this is not a
	   relocatable object file. */
	elf_flagelf (newelf,
				 ELF_C_SET,
				 (ehdr->e_type != ET_REL ? ELF_F_LAYOUT : 0));

	/* Finally write the file. */
    FAILIF_LIBELF(!dry_run && elf_update(newelf, ELF_C_WRITE) == -1, elf_update);

	if (shdr_info != NULL) {
		/* For some sections we might have created an table to map symbol
           table indices. */
       for (cnt = 1; cnt < shdr_info_len; ++cnt) {
            FREEIF(shdr_info[cnt].newsymidx);
            FREEIF(shdr_info[cnt].symse);
            if(shdr_info[cnt].dynsymst != NULL)
                ebl_strtabfree (shdr_info[cnt].dynsymst);
        }
		/* Free the memory. */
		FREE (shdr_info);
	}
    FREEIF(phdr_info);

    ebl_closebackend(ebl);

	/* Free other resources. */
	if (shst != NULL) ebl_strtabfree (shst);
    if (shstrtab_data != NULL)
        FREEIF(shstrtab_data->d_buf);
}
