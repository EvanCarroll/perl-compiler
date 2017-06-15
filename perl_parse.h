
#define INCPUSH_UNSHIFT			0x01
#define INCPUSH_ADD_OLD_VERS		0x02
#define INCPUSH_ADD_VERSIONED_SUB_DIRS	0x04
#define INCPUSH_ADD_ARCHONLY_SUB_DIRS	0x08
#define INCPUSH_NOT_BASEDIR		0x10
#define INCPUSH_CAN_RELOCATE		0x20
#define INCPUSH_ADD_SUB_DIRS	\
    (INCPUSH_ADD_VERSIONED_SUB_DIRS|INCPUSH_ADD_ARCHONLY_SUB_DIRS)


int
bc_perl_parse(pTHXx_ XSINIT_t xsinit, int argc, char **argv, char **env)
{
    dVAR;
    I32 oldscope;
    int ret;
    dJMPENV;

    PERL_ARGS_ASSERT_PERL_PARSE;
#ifndef MULTIPLICITY
    PERL_UNUSED_ARG(my_perl);
#endif
#if defined(USE_HASH_SEED) || defined(USE_HASH_SEED_EXPLICIT) || defined(USE_HASH_SEED_DEBUG)
    {
        const char * const s = PerlEnv_getenv("PERL_HASH_SEED_DEBUG");

        if (s && strEQ(s, "1")) {
            const unsigned char *seed= PERL_HASH_SEED;
            const unsigned char *seed_end= PERL_HASH_SEED + PERL_HASH_SEED_BYTES;
            PerlIO_printf(Perl_debug_log, "HASH_FUNCTION = %s HASH_SEED = 0x", PERL_HASH_FUNC);
            while (seed < seed_end) {
                PerlIO_printf(Perl_debug_log, "%02x", *seed++);
            }
#ifdef PERL_HASH_RANDOMIZE_KEYS
            PerlIO_printf(Perl_debug_log, " PERTURB_KEYS = %d (%s)",
                    PL_HASH_RAND_BITS_ENABLED,
                    PL_HASH_RAND_BITS_ENABLED == 0 ? "NO" : PL_HASH_RAND_BITS_ENABLED == 1 ? "RANDOM" : "DETERMINISTIC");
#endif
            PerlIO_printf(Perl_debug_log, "\n");
        }
    }
#endif /* #if defined(USE_HASH_SEED) || defined(USE_HASH_SEED_EXPLICIT) */

#ifdef __amigaos4__
    {
        struct NameTranslationInfo nti;
        __translate_amiga_to_unix_path_name(&argv[0],&nti); 
    }
#endif

    PL_origargc = argc;
    PL_origargv = argv;

    if (PL_origalen != 0) {
	PL_origalen = 1; /* don't use old PL_origalen if perl_parse() is called again */
    }
    else {
	/* Set PL_origalen be the sum of the contiguous argv[]
	 * elements plus the size of the env in case that it is
	 * contiguous with the argv[].  This is used in mg.c:Perl_magic_set()
	 * as the maximum modifiable length of $0.  In the worst case
	 * the area we are able to modify is limited to the size of
	 * the original argv[0].  (See below for 'contiguous', though.)
	 * --jhi */
	 const char *s = NULL;
	 int i;
	 const UV mask = ~(UV)(PTRSIZE-1);
         /* Do the mask check only if the args seem like aligned. */
	 const UV aligned =
	   (mask < ~(UV)0) && ((PTR2UV(argv[0]) & mask) == PTR2UV(argv[0]));

	 /* See if all the arguments are contiguous in memory.  Note
	  * that 'contiguous' is a loose term because some platforms
	  * align the argv[] and the envp[].  If the arguments look
	  * like non-aligned, assume that they are 'strictly' or
	  * 'traditionally' contiguous.  If the arguments look like
	  * aligned, we just check that they are within aligned
	  * PTRSIZE bytes.  As long as no system has something bizarre
	  * like the argv[] interleaved with some other data, we are
	  * fine.  (Did I just evoke Murphy's Law?)  --jhi */
	 if (PL_origargv && PL_origargc >= 1 && (s = PL_origargv[0])) {
	      while (*s) s++;
	      for (i = 1; i < PL_origargc; i++) {
		   if ((PL_origargv[i] == s + 1
#ifdef OS2
			|| PL_origargv[i] == s + 2
#endif 
			    )
		       ||
		       (aligned &&
			(PL_origargv[i] >  s &&
			 PL_origargv[i] <=
			 INT2PTR(char *, PTR2UV(s + PTRSIZE) & mask)))
			)
		   {
			s = PL_origargv[i];
			while (*s) s++;
		   }
		   else
			break;
	      }
	 }

#ifndef PERL_USE_SAFE_PUTENV
	 /* Can we grab env area too to be used as the area for $0? */
	 if (s && PL_origenviron && !PL_use_safe_putenv) {
	      if ((PL_origenviron[0] == s + 1)
		  ||
		  (aligned &&
		   (PL_origenviron[0] >  s &&
		    PL_origenviron[0] <=
		    INT2PTR(char *, PTR2UV(s + PTRSIZE) & mask)))
		 )
	      {
#ifndef OS2		/* ENVIRON is read by the kernel too. */
		   s = PL_origenviron[0];
		   while (*s) s++;
#endif
		   my_setenv("NoNe  SuCh", NULL);
		   /* Force copy of environment. */
		   for (i = 1; PL_origenviron[i]; i++) {
			if (PL_origenviron[i] == s + 1
			    ||
			    (aligned &&
			     (PL_origenviron[i] >  s &&
			      PL_origenviron[i] <=
			      INT2PTR(char *, PTR2UV(s + PTRSIZE) & mask)))
			   )
			{
			     s = PL_origenviron[i];
			     while (*s) s++;
			}
			else
			     break;
		   }
	      }
	 }
#endif /* !defined(PERL_USE_SAFE_PUTENV) */

	 PL_origalen = s ? s - PL_origargv[0] + 1 : 0;
    }

    if (PL_do_undump) {

	/* Come here if running an undumped a.out. */

	PL_origfilename = savepv(argv[0]);
	PL_do_undump = FALSE;
	cxstack_ix = -1;		/* start label stack again */
	init_ids();
	assert (!TAINT_get);
	TAINT;
	set_caret_X();
	TAINT_NOT;
	init_postdump_symbols(argc,argv,env);
	return 0;
    }

    if (PL_main_root) {
	op_free(PL_main_root);
	PL_main_root = NULL;
    }
    PL_main_start = NULL;
    SvREFCNT_dec(PL_main_cv);
    PL_main_cv = NULL;

    time(&PL_basetime);
    oldscope = PL_scopestack_ix;
    PL_dowarn = G_WARN_OFF;

    JMPENV_PUSH(ret);
    switch (ret) {
    case 0:
	bc_parse_body(env,xsinit);
	if (PL_unitcheckav) {
	    call_list(oldscope, PL_unitcheckav);
	}
	if (PL_checkav) {
	    PERL_SET_PHASE(PERL_PHASE_CHECK);
	    call_list(oldscope, PL_checkav);
	}
	ret = 0;
	break;
    case 1:
	STATUS_ALL_FAILURE;
	/* FALLTHROUGH */
    case 2:
	/* my_exit() was called */
	while (PL_scopestack_ix > oldscope)
	    LEAVE;
	FREETMPS;
	SET_CURSTASH(PL_defstash);
	if (PL_unitcheckav) {
	    call_list(oldscope, PL_unitcheckav);
	}
	if (PL_checkav) {
	    PERL_SET_PHASE(PERL_PHASE_CHECK);
	    call_list(oldscope, PL_checkav);
	}
	ret = STATUS_EXIT;
	break;
    case 3:
	PerlIO_printf(Perl_error_log, "panic: top_env\n");
	ret = 1;
	break;
    }
    JMPENV_POP;
    return ret;
}

STATIC void *
bc_parse_body(pTHX_ char **env, XSINIT_t xsinit)
{
    dVAR;
    PerlIO *rsfp;
    int argc = PL_origargc;
    char **argv = PL_origargv;
    const char *scriptname = NULL;
    bool dosearch = FALSE;
    char c;
    bool doextract = FALSE;
    const char *cddir = NULL;
#ifdef USE_SITECUSTOMIZE
    bool minus_f = FALSE;
#endif
    SV *linestr_sv = NULL;
    bool add_read_e_script = FALSE;
    U32 lex_start_flags = 0;

    PERL_SET_PHASE(PERL_PHASE_START);

    init_main_stash();

    {
	const char *s;
    for (argc--,argv++; argc > 0; argc--,argv++) {
	if (argv[0][0] != '-' || !argv[0][1])
	    break;
	s = argv[0]+1;
      reswitch:
	switch ((c = *s)) {
	case 'C':
#ifndef PERL_STRICT_CR
	case '\r':
#endif
	case ' ':
	case '0':
	case 'F':
	case 'a':
	case 'c':
	case 'd':
	case 'D':
	case 'h':
	case 'i':
	case 'l':
	case 'M':
	case 'm':
	case 'n':
	case 'p':
	case 's':
	case 'u':
	case 'U':
	case 'v':
	case 'W':
	case 'X':
	case 'w':
	    if ((s = moreswitches(s)))
		goto reswitch;
	    break;

	case 't':
#if defined(SILENT_NO_TAINT_SUPPORT)
            /* silently ignore */
#elif defined(NO_TAINT_SUPPORT)
            Perl_croak_nocontext("This perl was compiled without taint support. "
                       "Cowardly refusing to run with -t or -T flags");
#else
	    CHECK_MALLOC_TOO_LATE_FOR('t');
	    if( !TAINTING_get ) {
	         TAINT_WARN_set(TRUE);
	         TAINTING_set(TRUE);
	    }
#endif
	    s++;
	    goto reswitch;
	case 'T':
#if defined(SILENT_NO_TAINT_SUPPORT)
            /* silently ignore */
#elif defined(NO_TAINT_SUPPORT)
            Perl_croak_nocontext("This perl was compiled without taint support. "
                       "Cowardly refusing to run with -t or -T flags");
#else
	    CHECK_MALLOC_TOO_LATE_FOR('T');
	    TAINTING_set(TRUE);
	    TAINT_WARN_set(FALSE);
#endif
	    s++;
	    goto reswitch;

	case 'E':
	    PL_minus_E = TRUE;
	    /* FALLTHROUGH */
	case 'e':
	    forbid_setid('e', FALSE);
	    if (!PL_e_script) {
		PL_e_script = newSVpvs("");
		add_read_e_script = TRUE;
	    }
	    if (*++s)
		sv_catpv(PL_e_script, s);
	    else if (argv[1]) {
		sv_catpv(PL_e_script, argv[1]);
		argc--,argv++;
	    }
	    else
		Perl_croak(aTHX_ "No code specified for -%c", c);
	    sv_catpvs(PL_e_script, "\n");
	    break;

	case 'f':
#ifdef USE_SITECUSTOMIZE
	    minus_f = TRUE;
#endif
	    s++;
	    goto reswitch;

	case 'I':	/* -I handled both here and in moreswitches() */
	    forbid_setid('I', FALSE);
	    if (!*++s && (s=argv[1]) != NULL) {
		argc--,argv++;
	    }
	    if (s && *s) {
		STRLEN len = strlen(s);
		incpush(s, len, INCPUSH_ADD_SUB_DIRS|INCPUSH_ADD_OLD_VERS);
	    }
	    else
		Perl_croak(aTHX_ "No directory specified for -I");
	    break;
	case 'S':
	    forbid_setid('S', FALSE);
	    dosearch = TRUE;
	    s++;
	    goto reswitch;
	case 'V':
	    {
		SV *opts_prog;

		if (*++s != ':')  {
		    opts_prog = newSVpvs("use Config; Config::_V()");
		}
		else {
		    ++s;
		    opts_prog = Perl_newSVpvf(aTHX_
					      "use Config; Config::config_vars(qw%c%s%c)",
					      0, s, 0);
		    s += strlen(s);
		}
		Perl_av_create_and_push(aTHX_ &PL_preambleav, opts_prog);
		/* don't look for script or read stdin */
		scriptname = BIT_BUCKET;
		goto reswitch;
	    }
	case 'x':
	    doextract = TRUE;
	    s++;
	    if (*s)
		cddir = s;
	    break;
	case 0:
	    break;
	case '-':
	    if (!*++s || isSPACE(*s)) {
		argc--,argv++;
		goto switch_end;
	    }
	    /* catch use of gnu style long options.
	       Both of these exit immediately.  */
	    if (strEQ(s, "version"))
		minus_v();
	    if (strEQ(s, "help"))
		usage();
	    s--;
	    /* FALLTHROUGH */
	default:
	    Perl_croak(aTHX_ "Unrecognized switch: -%s  (-h will show valid options)",s);
	}
    }
    }

  switch_end:

    {
	char *s;

    if (
#ifndef SECURE_INTERNAL_GETENV
        !TAINTING_get &&
#endif
	(s = PerlEnv_getenv("PERL5OPT")))
    {
        /* s points to static memory in getenv(), which may be overwritten at
         * any time; use a mortal copy instead */
	s = SvPVX(sv_2mortal(newSVpv(s, 0)));

	while (isSPACE(*s))
	    s++;
	if (*s == '-' && *(s+1) == 'T') {
#if defined(SILENT_NO_TAINT_SUPPORT)
            /* silently ignore */
#elif defined(NO_TAINT_SUPPORT)
            Perl_croak_nocontext("This perl was compiled without taint support. "
                       "Cowardly refusing to run with -t or -T flags");
#else
	    CHECK_MALLOC_TOO_LATE_FOR('T');
	    TAINTING_set(TRUE);
            TAINT_WARN_set(FALSE);
#endif
	}
	else {
	    char *popt_copy = NULL;
	    while (s && *s) {
	        const char *d;
		while (isSPACE(*s))
		    s++;
		if (*s == '-') {
		    s++;
		    if (isSPACE(*s))
			continue;
		}
		d = s;
		if (!*s)
		    break;
		if (!strchr("CDIMUdmtwW", *s))
		    Perl_croak(aTHX_ "Illegal switch in PERL5OPT: -%c", *s);
		while (++s && *s) {
		    if (isSPACE(*s)) {
			if (!popt_copy) {
			    popt_copy = SvPVX(sv_2mortal(newSVpv(d,0)));
			    s = popt_copy + (s - d);
			    d = popt_copy;
			}
		        *s++ = '\0';
			break;
		    }
		}
		if (*d == 't') {
#if defined(SILENT_NO_TAINT_SUPPORT)
            /* silently ignore */
#elif defined(NO_TAINT_SUPPORT)
                    Perl_croak_nocontext("This perl was compiled without taint support. "
                               "Cowardly refusing to run with -t or -T flags");
#else
		    if( !TAINTING_get) {
		        TAINT_WARN_set(TRUE);
		        TAINTING_set(TRUE);
		    }
#endif
		} else {
		    moreswitches(d);
		}
	    }
	}
    }
    }

    /* Set $^X early so that it can be used for relocatable paths in @INC  */
    /* and for SITELIB_EXP in USE_SITECUSTOMIZE                            */
    assert (!TAINT_get);
    TAINT;
    set_caret_X();
    TAINT_NOT;

#if defined(USE_SITECUSTOMIZE)
    if (!minus_f) {
	/* The games with local $! are to avoid setting errno if there is no
	   sitecustomize script.  "q%c...%c", 0, ..., 0 becomes "q\0...\0",
	   ie a q() operator with a NUL byte as a the delimiter. This avoids
	   problems with pathnames containing (say) '  */
#  ifdef PERL_IS_MINIPERL
	AV *const inc = GvAV(PL_incgv);
	SV **const inc0 = inc ? av_fetch(inc, 0, FALSE) : NULL;

	if (inc0) {
            /* if lib/buildcustomize.pl exists, it should not fail. If it does,
               it should be reported immediately as a build failure.  */
	    (void)Perl_av_create_and_unshift_one(aTHX_ &PL_preambleav,
						 Perl_newSVpvf(aTHX_
		"BEGIN { my $f = q%c%s%"SVf"/buildcustomize.pl%c; "
			"do {local $!; -f $f }"
			" and do $f || die $@ || qq '$f: $!' }",
                                0, (TAINTING_get ? "./" : ""), SVfARG(*inc0), 0));
	}
#  else
	/* SITELIB_EXP is a function call on Win32.  */
	const char *const raw_sitelib = SITELIB_EXP;
	if (raw_sitelib) {
	    /* process .../.. if PERL_RELOCATABLE_INC is defined */
	    SV *sitelib_sv = mayberelocate(raw_sitelib, strlen(raw_sitelib),
					   INCPUSH_CAN_RELOCATE);
	    const char *const sitelib = SvPVX(sitelib_sv);
	    (void)Perl_av_create_and_unshift_one(aTHX_ &PL_preambleav,
						 Perl_newSVpvf(aTHX_
							       "BEGIN { do {local $!; -f q%c%s/sitecustomize.pl%c} && do q%c%s/sitecustomize.pl%c }",
							       0, SVfARG(sitelib), 0,
							       0, SVfARG(sitelib), 0));
	    assert (SvREFCNT(sitelib_sv) == 1);
	    SvREFCNT_dec(sitelib_sv);
	}
#  endif
    }
#endif

    if (!scriptname)
	scriptname = argv[0];
    if (PL_e_script) {
	argc++,argv--;
	scriptname = BIT_BUCKET;	/* don't look for script or read stdin */
    }
    else if (scriptname == NULL) {
#ifdef MSDOS
	if ( PerlLIO_isatty(PerlIO_fileno(PerlIO_stdin())) )
	    moreswitches("h");
#endif
	scriptname = "-";
    }

    assert (!TAINT_get);
    init_perllib();

    {
	bool suidscript = FALSE;

	rsfp = open_script(scriptname, dosearch, &suidscript);
	if (!rsfp) {
	    rsfp = PerlIO_stdin();
	    lex_start_flags = LEX_DONT_CLOSE_RSFP;
	}

	validate_suid(rsfp);

#ifndef PERL_MICRO
#  if defined(SIGCHLD) || defined(SIGCLD)
	{
#  ifndef SIGCHLD
#    define SIGCHLD SIGCLD
#  endif
	    Sighandler_t sigstate = rsignal_state(SIGCHLD);
	    if (sigstate == (Sighandler_t) SIG_IGN) {
		Perl_ck_warner(aTHX_ packWARN(WARN_SIGNAL),
			       "Can't ignore signal CHLD, forcing to default");
		(void)rsignal(SIGCHLD, (Sighandler_t)SIG_DFL);
	    }
	}
#  endif
#endif

	if (doextract) {

	    /* This will croak if suidscript is true, as -x cannot be used with
	       setuid scripts.  */
	    forbid_setid('x', suidscript);
	    /* Hence you can't get here if suidscript is true */

	    linestr_sv = newSV_type(SVt_PV);
	    lex_start_flags |= LEX_START_COPIED;
	    find_beginning(linestr_sv, rsfp);
	    if (cddir && PerlDir_chdir( (char *)cddir ) < 0)
		Perl_croak(aTHX_ "Can't chdir to %s",cddir);
	}
    }

    PL_main_cv = PL_compcv = MUTABLE_CV(newSV_type(SVt_PVCV));
    CvUNIQUE_on(PL_compcv);

    CvPADLIST_set(PL_compcv, pad_new(0));

    PL_isarev = newHV();

    boot_core_PerlIO();
    boot_core_UNIVERSAL();
    boot_core_mro();
    newXS("Internals::V", S_Internals_V, __FILE__);

    if (xsinit)
	(*xsinit)(aTHX);	/* in case linked C routines want magical variables */
#ifndef PERL_MICRO
#if defined(VMS) || defined(WIN32) || defined(DJGPP) || defined(__CYGWIN__) || defined(SYMBIAN)
    init_os_extras();
#endif
#endif

#ifdef USE_SOCKS
#   ifdef HAS_SOCKS5_INIT
    socks5_init(argv[0]);
#   else
    SOCKSinit(argv[0]);
#   endif
#endif

    init_predump_symbols();
    /* init_postdump_symbols not currently designed to be called */
    /* more than once (ENV isn't cleared first, for example)	 */
    /* But running with -u leaves %ENV & @ARGV undefined!    XXX */
    if (!PL_do_undump)
	init_postdump_symbols(argc,argv,env);

    /* PL_unicode is turned on by -C, or by $ENV{PERL_UNICODE},
     * or explicitly in some platforms.
     * locale.c:Perl_init_i18nl10n() if the environment
     * look like the user wants to use UTF-8. */
#if defined(__SYMBIAN32__)
    PL_unicode = PERL_UNICODE_STD_FLAG; /* See PERL_SYMBIAN_CONSOLE_UTF8. */
#endif
#  ifndef PERL_IS_MINIPERL
    if (PL_unicode) {
	 /* Requires init_predump_symbols(). */
	 if (!(PL_unicode & PERL_UNICODE_LOCALE_FLAG) || PL_utf8locale) {
	      IO* io;
	      PerlIO* fp;
	      SV* sv;

	      /* Turn on UTF-8-ness on STDIN, STDOUT, STDERR
	       * and the default open disciplines. */
	      if ((PL_unicode & PERL_UNICODE_STDIN_FLAG) &&
		  PL_stdingv  && (io = GvIO(PL_stdingv)) &&
		  (fp = IoIFP(io)))
		   PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");
	      if ((PL_unicode & PERL_UNICODE_STDOUT_FLAG) &&
		  PL_defoutgv && (io = GvIO(PL_defoutgv)) &&
		  (fp = IoOFP(io)))
		   PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");
	      if ((PL_unicode & PERL_UNICODE_STDERR_FLAG) &&
		  PL_stderrgv && (io = GvIO(PL_stderrgv)) &&
		  (fp = IoOFP(io)))
		   PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");
	      if ((PL_unicode & PERL_UNICODE_INOUT_FLAG) &&
		  (sv = GvSV(gv_fetchpvs("\017PEN", GV_ADD|GV_NOTQUAL,
					 SVt_PV)))) {
		   U32 in  = PL_unicode & PERL_UNICODE_IN_FLAG;
		   U32 out = PL_unicode & PERL_UNICODE_OUT_FLAG;
		   if (in) {
			if (out)
			     sv_setpvs(sv, ":utf8\0:utf8");
			else
			     sv_setpvs(sv, ":utf8\0");
		   }
		   else if (out)
			sv_setpvs(sv, "\0:utf8");
		   SvSETMAGIC(sv);
	      }
	 }
    }
#endif

    {
	const char *s;
    if ((s = PerlEnv_getenv("PERL_SIGNALS"))) {
	 if (strEQ(s, "unsafe"))
	      PL_signals |=  PERL_SIGNALS_UNSAFE_FLAG;
	 else if (strEQ(s, "safe"))
	      PL_signals &= ~PERL_SIGNALS_UNSAFE_FLAG;
	 else
	      Perl_croak(aTHX_ "PERL_SIGNALS illegal: \"%s\"", s);
    }
    }


    lex_start(linestr_sv, rsfp, lex_start_flags);
    SvREFCNT_dec(linestr_sv);

    PL_subname = newSVpvs("main");

    if (add_read_e_script)
	filter_add(read_e_script, NULL);

    /* now parse the script */

    SETERRNO(0,SS_NORMAL);
    if (yyparse(GRAMPROG) || PL_parser->error_count) {
	if (PL_minus_c)
	    Perl_croak(aTHX_ "%s had compilation errors.\n", PL_origfilename);
	else {
	    Perl_croak(aTHX_ "Execution of %s aborted due to compilation errors.\n",
		       PL_origfilename);
	}
    }
    CopLINE_set(PL_curcop, 0);
    SET_CURSTASH(PL_defstash);
    if (PL_e_script) {
	SvREFCNT_dec(PL_e_script);
	PL_e_script = NULL;
    }

    if (PL_do_undump)
	my_unexec();

    if (isWARN_ONCE) {
	SAVECOPFILE(PL_curcop);
	SAVECOPLINE(PL_curcop);
	gv_check(PL_defstash);
    }

    LEAVE;
    FREETMPS;

#ifdef MYMALLOC
    {
	const char *s;
        UV uv;
        s = PerlEnv_getenv("PERL_DEBUG_MSTATS");
        if (s && grok_atoUV(s, &uv, NULL) && uv >= 2)
            dump_mstats("after compilation:");
    }
#endif

    ENTER;
    PL_restartjmpenv = NULL;
    PL_restartop = 0;
    return NULL;
}
