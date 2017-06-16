
void bc_parse_body(char **env, XSINIT_t xsinit);
static PerlIO * open_script(pTHX_ const char *scriptname, bool dosearch, bool *suidscript);
static void init_postdump_symbols(pTHX_ int argc, char **argv, char **env);
static void forbid_setid(pTHX_ const char flag, const bool suidscript);
static void incpush(pTHX_ const char *const dir, STRLEN len, U32 flags);
static void init_perllib(pTHX);
static void validate_suid(pTHX_ PerlIO *rsfp);
static void find_beginning(pTHX_ SV* linestr_sv, PerlIO *rsfp);
static void init_predump_symbols(pTHX);
static SV * mayberelocate(pTHX_ const char *const dir, STRLEN len, U32 flags);
static SV * S_incpush_if_exists(pTHX_ AV *const av, SV *dir, SV *const stem);
static void S_Internals_V(pTHX_ CV *cv);
#define NEVER Perl_croak_nocontext("Shouldn't get here\n\n");

#define incpush_use_sep(a,b,c)  S_incpush_use_sep(aTHX_ a,b,c)
static void S_incpush_use_sep(pTHX_ const char *p, STRLEN len, U32 flags);


#define SET_CURSTASH(newstash)                       \
	if (PL_curstash != newstash) {                \
	    SvREFCNT_dec(PL_curstash);                 \
	    PL_curstash = (HV *)SvREFCNT_inc(newstash); \
	}



#define INCPUSH_UNSHIFT			0x01
#define INCPUSH_ADD_OLD_VERS		0x02
#define INCPUSH_ADD_VERSIONED_SUB_DIRS	0x04
#define INCPUSH_ADD_ARCHONLY_SUB_DIRS	0x08
#define INCPUSH_NOT_BASEDIR		0x10
#define INCPUSH_CAN_RELOCATE		0x20
#define INCPUSH_ADD_SUB_DIRS	(INCPUSH_ADD_VERSIONED_SUB_DIRS|INCPUSH_ADD_ARCHONLY_SUB_DIRS)


int
bc_perl_parse(pTHXx_ XSINIT_t xsinit, int argc, char **argv, char **env)
{
    dVAR;
    int ret;
    dJMPENV;

    PERL_ARGS_ASSERT_PERL_PARSE;
    PERL_UNUSED_ARG(my_perl);

    PL_origargc = argc;
    PL_origargv = argv;

    /* START: Determine how long $0 is allowed to be */
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
		   s = PL_origenviron[0];
		   while (*s) s++;
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
    
    /* END: Determine how long $0 is allowed to be */

	PL_main_root = NULL; /* We should really be setting PL_main_root statically */
    PL_main_start = NULL;
    PL_main_cv = NULL;

    time(&PL_basetime);
    PL_dowarn = G_WARN_OFF;

    JMPENV_PUSH(ret);
    if(ret) {
        PerlIO_printf(Perl_error_log, "panic: jmpenv failed!\n");
    }
    else {
        bc_parse_body(env,xsinit);
        ret = 0;
    }
    JMPENV_POP;
    return ret;
}

void bc_parse_body(char **env, XSINIT_t xsinit)
{
    dVAR;
    PerlIO *rsfp;
    int argc = PL_origargc;
    char **argv = PL_origargv;
    const char *scriptname = NULL;
    bool dosearch = FALSE;
    bool doextract = FALSE;
    const char *cddir = NULL;
    SV *linestr_sv = NULL;
    U32 lex_start_flags = 0;

    PERL_SET_PHASE(PERL_PHASE_START);

    /* init_main_stash(); PL_defstash setup */
    PL_curstash = PL_defstash;

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
    assert (!TAINT_get);
    TAINT;
    set_caret_X();
    TAINT_NOT;

    if (!scriptname)
	scriptname = argv[0];
    if (PL_e_script) {
	argc++,argv--;
	scriptname = BIT_BUCKET;	/* don't look for script or read stdin */
    }
    else if (scriptname == NULL) {
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
#if defined(VMS) || defined(WIN32) || defined(DJGPP) || defined(__CYGWIN__) || defined(SYMBIAN)
    init_os_extras();
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

    /* now parse the script */

    SETERRNO(0,SS_NORMAL);
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
}

static PerlIO * open_script(pTHX_ const char *scriptname, bool dosearch, bool *suidscript)
{
    int fdscript = -1;
    PerlIO *rsfp = NULL;
    Stat_t tmpstatbuf;
    int fd;

    if (PL_e_script) {
	PL_origfilename = savepvs("-e");
    }
    else {
        const char *s;
        UV uv;
	/* if find_script() returns, it returns a malloc()-ed value */
	scriptname = PL_origfilename = find_script(scriptname, dosearch, NULL, 1);

	if (strnEQ(scriptname, "/dev/fd/", 8)
            && isDIGIT(scriptname[8])
            && grok_atoUV(scriptname + 8, &uv, &s)
            && uv <= PERL_INT_MAX
        ) {
            fdscript = (int)uv;
	    if (*s) {
		/* PSz 18 Feb 04
		 * Tell apart "normal" usage of fdscript, e.g.
		 * with bash on FreeBSD:
		 *   perl <( echo '#!perl -DA'; echo 'print "$0\n"')
		 * from usage in suidperl.
		 * Does any "normal" usage leave garbage after the number???
		 * Is it a mistake to use a similar /dev/fd/ construct for
		 * suidperl?
		 */
		*suidscript = TRUE;
		/* PSz 20 Feb 04  
		 * Be supersafe and do some sanity-checks.
		 * Still, can we be sure we got the right thing?
		 */
		if (*s != '/') {
		    Perl_croak(aTHX_ "Wrong syntax (suid) fd script name \"%s\"\n", s);
		}
		if (! *(s+1)) {
		    Perl_croak(aTHX_ "Missing (suid) fd script name\n");
		}
		scriptname = savepv(s + 1);
		Safefree(PL_origfilename);
		PL_origfilename = (char *)scriptname;
	    }
	}
    }

    CopFILE_free(PL_curcop);
    CopFILE_set(PL_curcop, PL_origfilename);
    if (*PL_origfilename == '-' && PL_origfilename[1] == '\0')
	scriptname = (char *)"";
    if (fdscript >= 0) {
	rsfp = PerlIO_fdopen(fdscript,PERL_SCRIPT_MODE);
    }
    else if (!*scriptname) {
	forbid_setid(0, *suidscript);
	return NULL;
    }
    else {
#ifdef FAKE_BIT_BUCKET
	/* This hack allows one not to have /dev/null (or BIT_BUCKET as it
	 * is called) and still have the "-e" work.  (Believe it or not,
	 * a /dev/null is required for the "-e" to work because source
	 * filter magic is used to implement it. ) This is *not* a general
	 * replacement for a /dev/null.  What we do here is create a temp
	 * file (an empty file), open up that as the script, and then
	 * immediately close and unlink it.  Close enough for jazz. */ 
#define FAKE_BIT_BUCKET_PREFIX "/tmp/perlnull-"
#define FAKE_BIT_BUCKET_SUFFIX "XXXXXXXX"
#define FAKE_BIT_BUCKET_TEMPLATE FAKE_BIT_BUCKET_PREFIX FAKE_BIT_BUCKET_SUFFIX
	char tmpname[sizeof(FAKE_BIT_BUCKET_TEMPLATE)] = {
	    FAKE_BIT_BUCKET_TEMPLATE
	};
	const char * const err = "Failed to create a fake bit bucket";
	if (strEQ(scriptname, BIT_BUCKET)) {
#ifdef HAS_MKSTEMP /* Hopefully mkstemp() is safe here. */
            int old_umask = umask(0177);
	    int tmpfd = mkstemp(tmpname);
            umask(old_umask);
	    if (tmpfd > -1) {
		scriptname = tmpname;
		close(tmpfd);
	    } else
		Perl_croak(aTHX_ err);
#else
#  ifdef HAS_MKTEMP
	    scriptname = mktemp(tmpname);
	    if (!scriptname)
		Perl_croak(aTHX_ err);
#  endif
#endif
	}
#endif
	rsfp = PerlIO_open(scriptname,PERL_SCRIPT_MODE);
#ifdef FAKE_BIT_BUCKET
	if (memEQ(scriptname, FAKE_BIT_BUCKET_PREFIX,
		  sizeof(FAKE_BIT_BUCKET_PREFIX) - 1)
	    && strlen(scriptname) == sizeof(tmpname) - 1) {
	    unlink(scriptname);
	}
	scriptname = BIT_BUCKET;
#endif
    }
    if (!rsfp) {
	/* PSz 16 Sep 03  Keep neat error message */
	if (PL_e_script)
	    Perl_croak(aTHX_ "Can't open "BIT_BUCKET": %s\n", Strerror(errno));
	else
	    Perl_croak(aTHX_ "Can't open perl script \"%s\": %s\n",
		    CopFILE(PL_curcop), Strerror(errno));
    }
    fd = PerlIO_fileno(rsfp);
#if defined(HAS_FCNTL) && defined(F_SETFD) && defined(FD_CLOEXEC)
    if (fd >= 0) {
        /* ensure close-on-exec */
        if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) {
            Perl_croak(aTHX_ "Can't open perl script \"%s\": %s\n",
                       CopFILE(PL_curcop), Strerror(errno));
        }
    }
#endif

    if (fd < 0 ||
        (PerlLIO_fstat(fd, &tmpstatbuf) >= 0
         && S_ISDIR(tmpstatbuf.st_mode)))
        Perl_croak(aTHX_ "Can't open perl script \"%s\": %s\n",
            CopFILE(PL_curcop),
            Strerror(EISDIR));

    return rsfp;
}

STATIC void init_postdump_symbols(pTHX_ int argc, char **argv, char **env)
{
#ifdef USE_ITHREADS
    dVAR;
#endif
    GV* tmpgv;

    PL_toptarget = newSV_type(SVt_PVIV);
    sv_setpvs(PL_toptarget, "");
    PL_bodytarget = newSV_type(SVt_PVIV);
    sv_setpvs(PL_bodytarget, "");
    PL_formtarget = PL_bodytarget;

    TAINT;

    init_argv_symbols(argc,argv);

    if ((tmpgv = gv_fetchpvs("0", GV_ADD|GV_NOTQUAL, SVt_PV))) {
	sv_setpv(GvSV(tmpgv),PL_origfilename);
    }
    if ((PL_envgv = gv_fetchpvs("ENV", GV_ADD|GV_NOTQUAL, SVt_PVHV))) {
	HV *hv;
	bool env_is_not_environ;
	SvREFCNT_inc_simple_void_NN(PL_envgv);
	GvMULTI_on(PL_envgv);
	hv = GvHVn(PL_envgv);
	hv_magic(hv, NULL, PERL_MAGIC_env);
#ifdef USE_ENVIRON_ARRAY
	/* Note that if the supplied env parameter is actually a copy
	   of the global environ then it may now point to free'd memory
	   if the environment has been modified since. To avoid this
	   problem we treat env==NULL as meaning 'use the default'
	*/
	if (!env)
	    env = environ;
	env_is_not_environ = env != environ;
	if (env_is_not_environ
	   )
	{
	    environ[0] = NULL;
	}
	if (env) {
	  char *s, *old_var;
          STRLEN nlen;
	  SV *sv;
          HV *dups = newHV();

	  for (; *env; env++) {
	    old_var = *env;

	    if (!(s = strchr(old_var,'=')) || s == old_var)
		continue;
            nlen = s - old_var;

            if (hv_exists(hv, old_var, nlen)) {
                const char *name = savepvn(old_var, nlen);

                /* make sure we use the same value as getenv(), otherwise code that
                   uses getenv() (like setlocale()) might see a different value to %ENV
                 */
                sv = newSVpv(PerlEnv_getenv(name), 0);

                /* keep a count of the dups of this name so we can de-dup environ later */
                if (hv_exists(dups, name, nlen))
                    ++SvIVX(*hv_fetch(dups, name, nlen, 0));
                else
                    (void)hv_store(dups, name, nlen, newSViv(1), 0);

                Safefree(name);
            }
            else {
                sv = newSVpv(s+1, 0);
            }
	    (void)hv_store(hv, old_var, nlen, sv, 0);
	    if (env_is_not_environ)
	        mg_set(sv);
	  }
          if (HvKEYS(dups)) {
              /* environ has some duplicate definitions, remove them */
              HE *entry;
              hv_iterinit(dups);
              while ((entry = hv_iternext_flags(dups, 0))) {
                  STRLEN nlen;
                  const char *name = HePV(entry, nlen);
                  IV count = SvIV(HeVAL(entry));
                  IV i;
                  SV **valp = hv_fetch(hv, name, nlen, 0);

                  assert(valp);

                  /* try to remove any duplicate names, depending on the
                   * implementation used in my_setenv() the iteration might
                   * not be necessary, but let's be safe.
                   */
                  for (i = 0; i < count; ++i)
                      my_setenv(name, 0);

                  /* and set it back to the value we set $ENV{name} to */
                  my_setenv(name, SvPV_nolen(*valp));
              }
          }
          SvREFCNT_dec_NN(dups);
      }
#endif /* USE_ENVIRON_ARRAY */
    }
    TAINT_NOT;

    /* touch @F array to prevent spurious warnings 20020415 MJD */
    if (PL_minus_a) {
      (void) get_av("main::F", GV_ADD | GV_ADDMULTI);
    }
}

static void forbid_setid(pTHX_ const char flag, const bool suidscript)
{
    char string[3] = "-x";
    const char *message = "program input from stdin";

    PERL_UNUSED_CONTEXT;
    if (flag) {
	string[1] = flag;
	message = string;
    }

#ifdef SETUID_SCRIPTS_ARE_SECURE_NOW
    if (PerlProc_getuid() != PerlProc_geteuid())
        Perl_croak(aTHX_ "No %s allowed while running setuid", message);
    if (PerlProc_getgid() != PerlProc_getegid())
        Perl_croak(aTHX_ "No %s allowed while running setgid", message);
#endif /* SETUID_SCRIPTS_ARE_SECURE_NOW */
    if (suidscript)
        Perl_croak(aTHX_ "No %s allowed with (suid) fdscript", message);
}

static void incpush(pTHX_ const char *const dir, STRLEN len, U32 flags)
{
#ifndef PERL_IS_MINIPERL
    const U8 using_sub_dirs
	= (U8)flags & (INCPUSH_ADD_VERSIONED_SUB_DIRS
		       |INCPUSH_ADD_ARCHONLY_SUB_DIRS|INCPUSH_ADD_OLD_VERS);
    const U8 add_versioned_sub_dirs
	= (U8)flags & INCPUSH_ADD_VERSIONED_SUB_DIRS;
    const U8 add_archonly_sub_dirs
	= (U8)flags & INCPUSH_ADD_ARCHONLY_SUB_DIRS;
#ifdef PERL_INC_VERSION_LIST
    const U8 addoldvers  = (U8)flags & INCPUSH_ADD_OLD_VERS;
#endif
#endif
    const U8 unshift     = (U8)flags & INCPUSH_UNSHIFT;
    const U8 push_basedir = (flags & INCPUSH_NOT_BASEDIR) ? 0 : 1;
    AV *const inc = GvAVn(PL_incgv);

    assert(len > 0);

    /* Could remove this vestigial extra block, if we don't mind a lot of
       re-indenting diff noise.  */
    {
	SV *const libdir = mayberelocate(dir, len, flags);
	/* Change 20189146be79a0596543441fa369c6bf7f85103f, to fix RT#6665,
	   arranged to unshift #! line -I onto the front of @INC. However,
	   -I can add version and architecture specific libraries, and they
	   need to go first. The old code assumed that it was always
	   pushing. Hence to make it work, need to push the architecture
	   (etc) libraries onto a temporary array, then "unshift" that onto
	   the front of @INC.  */
#ifndef PERL_IS_MINIPERL
	AV *const av = (using_sub_dirs) ? (unshift ? newAV() : inc) : NULL;

	/*
	 * BEFORE pushing libdir onto @INC we may first push version- and
	 * archname-specific sub-directories.
	 */
	if (using_sub_dirs) {
	    SV *subdir = newSVsv(libdir);
#ifdef PERL_INC_VERSION_LIST
	    /* Configure terminates PERL_INC_VERSION_LIST with a NULL */
	    const char * const incverlist[] = { PERL_INC_VERSION_LIST };
	    const char * const *incver;
#endif

	    if (add_versioned_sub_dirs) {
		/* .../version/archname if -d .../version/archname */
		sv_catpvs(subdir, "/" PERL_FS_VERSION "/" ARCHNAME);
		subdir = S_incpush_if_exists(aTHX_ av, subdir, libdir);

		/* .../version if -d .../version */
		sv_catpvs(subdir, "/" PERL_FS_VERSION);
		subdir = S_incpush_if_exists(aTHX_ av, subdir, libdir);
	    }

#ifdef PERL_INC_VERSION_LIST
	    if (addoldvers) {
		for (incver = incverlist; *incver; incver++) {
		    /* .../xxx if -d .../xxx */
		    Perl_sv_catpvf(aTHX_ subdir, "/%s", *incver);
		    subdir = S_incpush_if_exists(aTHX_ av, subdir, libdir);
		}
	    }
#endif

	    if (add_archonly_sub_dirs) {
		/* .../archname if -d .../archname */
		sv_catpvs(subdir, "/" ARCHNAME);
		subdir = S_incpush_if_exists(aTHX_ av, subdir, libdir);

	    }

	    assert (SvREFCNT(subdir) == 1);
	    SvREFCNT_dec(subdir);
	}
#endif /* !PERL_IS_MINIPERL */
	/* finally add this lib directory at the end of @INC */
	if (unshift) {
#ifdef PERL_IS_MINIPERL
	    const Size_t extra = 0;
#else
	    Size_t extra = av_tindex(av) + 1;
#endif
	    av_unshift(inc, extra + push_basedir);
	    if (push_basedir)
		av_store(inc, extra, libdir);
#ifndef PERL_IS_MINIPERL
	    while (extra--) {
		/* av owns a reference, av_store() expects to be donated a
		   reference, and av expects to be sane when it's cleared.
		   If I wanted to be naughty and wrong, I could peek inside the
		   implementation of av_clear(), realise that it uses
		   SvREFCNT_dec() too, so av's array could be a run of NULLs,
		   and so directly steal from it (with a memcpy() to inc, and
		   then memset() to NULL them out. But people copy code from the
		   core expecting it to be best practise, so let's use the API.
		   Although studious readers will note that I'm not checking any
		   return codes.  */
		av_store(inc, extra, SvREFCNT_inc(*av_fetch(av, extra, FALSE)));
	    }
	    SvREFCNT_dec(av);
#endif
	}
	else if (push_basedir) {
	    av_push(inc, libdir);
	}

	if (!push_basedir) {
	    assert (SvREFCNT(libdir) == 1);
	    SvREFCNT_dec(libdir);
	}
    }
}

static void init_perllib(pTHX)
{
#ifndef VMS
    const char *perl5lib = NULL;
#endif
    const char *s;
#if defined(WIN32) && !defined(PERL_IS_MINIPERL)
    STRLEN len;
#endif

    if (!TAINTING_get) {
#ifndef VMS
	perl5lib = PerlEnv_getenv("PERL5LIB");
/*
 * It isn't possible to delete an environment variable with
 * PERL_USE_SAFE_PUTENV set unless unsetenv() is also available, so in that
 * case we treat PERL5LIB as undefined if it has a zero-length value.
 */
#if defined(PERL_USE_SAFE_PUTENV) && ! defined(HAS_UNSETENV)
	if (perl5lib && *perl5lib != '\0')
#else
	if (perl5lib)
#endif
	    incpush_use_sep(perl5lib, 0, INCPUSH_ADD_SUB_DIRS);
	else {
	    s = PerlEnv_getenv("PERLLIB");
	    if (s)
		incpush_use_sep(s, 0, 0);
	}
#else /* VMS */
	/* Treat PERL5?LIB as a possible search list logical name -- the
	 * "natural" VMS idiom for a Unix path string.  We allow each
	 * element to be a set of |-separated directories for compatibility.
	 */
	char buf[256];
	int idx = 0;
	if (vmstrnenv("PERL5LIB",buf,0,NULL,0))
	    do {
		incpush_use_sep(buf, 0, INCPUSH_ADD_SUB_DIRS);
	    } while (vmstrnenv("PERL5LIB",buf,++idx,NULL,0));
	else {
	    while (vmstrnenv("PERLLIB",buf,idx++,NULL,0))
		incpush_use_sep(buf, 0, 0);
	}
#endif /* VMS */
    }

#ifndef PERL_IS_MINIPERL
    /* miniperl gets just -I..., the split of $ENV{PERL5LIB}, and "." in @INC
       (and not the architecture specific directories from $ENV{PERL5LIB}) */

/* Use the ~-expanded versions of APPLLIB (undocumented),
    SITEARCH, SITELIB, VENDORARCH, VENDORLIB, ARCHLIB and PRIVLIB
*/

S_incpush_use_sep(aTHX_ STR_WITH_LEN("/usr/local/cpanel"), INCPUSH_CAN_RELOCATE);

#ifdef PERL_VENDORARCH_EXP
    /* vendorarch is always relative to vendorlib on Windows for
     * DLL-based path intuition to work correctly */
#  if !defined(WIN32)
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(PERL_VENDORARCH_EXP),
		      INCPUSH_CAN_RELOCATE);
#  endif
#endif

#ifdef PERL_VENDORLIB_EXP
#  if defined(WIN32)
    /* this picks up vendorarch as well */
	s = PerlEnv_vendorlib_path(PERL_FS_VERSION, &len);
	if (s)
	    incpush_use_sep(s, len, INCPUSH_ADD_SUB_DIRS|INCPUSH_CAN_RELOCATE);
#  else
	S_incpush_use_sep(aTHX_ STR_WITH_LEN(PERL_VENDORLIB_EXP),
			  INCPUSH_CAN_RELOCATE);
#  endif
#endif

#ifdef ARCHLIB_EXP
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(ARCHLIB_EXP), INCPUSH_CAN_RELOCATE);
#endif

#ifndef PRIVLIB_EXP
#  define PRIVLIB_EXP "/usr/local/lib/perl5:/usr/local/lib/perl"
#endif

#if defined(WIN32)
    s = PerlEnv_lib_path(PERL_FS_VERSION, &len);
    if (s)
	incpush_use_sep(s, len, INCPUSH_ADD_SUB_DIRS|INCPUSH_CAN_RELOCATE);
#else
#  ifdef NETWARE
    S_incpush_use_sep(aTHX_ PRIVLIB_EXP, 0, INCPUSH_CAN_RELOCATE);
#  else
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(PRIVLIB_EXP), INCPUSH_CAN_RELOCATE);
#  endif
#endif

/* Site arch at the end for cpanel desired ordering */
#ifdef SITEARCH_EXP
       S_incpush_use_sep(aTHX_ STR_WITH_LEN(SITEARCH_EXP),
                         INCPUSH_CAN_RELOCATE);
#endif

#ifdef SITELIB_EXP
       S_incpush_use_sep(aTHX_ STR_WITH_LEN(SITELIB_EXP), INCPUSH_CAN_RELOCATE);
#endif

#ifdef PERL_OTHERLIBDIRS
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(PERL_OTHERLIBDIRS),
		      INCPUSH_ADD_VERSIONED_SUB_DIRS|INCPUSH_NOT_BASEDIR
		      |INCPUSH_CAN_RELOCATE);
#endif

    if (!TAINTING_get) {
#ifndef VMS
/*
 * It isn't possible to delete an environment variable with
 * PERL_USE_SAFE_PUTENV set unless unsetenv() is also available, so in that
 * case we treat PERL5LIB as undefined if it has a zero-length value.
 */
#if defined(PERL_USE_SAFE_PUTENV) && ! defined(HAS_UNSETENV)
	if (perl5lib && *perl5lib != '\0')
#else
	if (perl5lib)
#endif
	    incpush_use_sep(perl5lib, 0,
			    INCPUSH_ADD_OLD_VERS|INCPUSH_NOT_BASEDIR);
#else /* VMS */
	/* Treat PERL5?LIB as a possible search list logical name -- the
	 * "natural" VMS idiom for a Unix path string.  We allow each
	 * element to be a set of |-separated directories for compatibility.
	 */
	char buf[256];
	int idx = 0;
	if (vmstrnenv("PERL5LIB",buf,0,NULL,0))
	    do {
		incpush_use_sep(buf, 0,
				INCPUSH_ADD_OLD_VERS|INCPUSH_NOT_BASEDIR);
	    } while (vmstrnenv("PERL5LIB",buf,++idx,NULL,0));
#endif /* VMS */
    }

#if defined(SITELIB_STEM) && defined(PERL_INC_VERSION_LIST)
    /* Search for version-specific dirs below here */
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(SITELIB_STEM),
		      INCPUSH_ADD_OLD_VERS|INCPUSH_CAN_RELOCATE);
#endif


#if defined(PERL_VENDORLIB_STEM) && defined(PERL_INC_VERSION_LIST)
    /* Search for version-specific dirs below here */
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(PERL_VENDORLIB_STEM),
		      INCPUSH_ADD_OLD_VERS|INCPUSH_CAN_RELOCATE);
#endif

#ifdef PERL_OTHERLIBDIRS
    S_incpush_use_sep(aTHX_ STR_WITH_LEN(PERL_OTHERLIBDIRS),
		      INCPUSH_ADD_OLD_VERS|INCPUSH_ADD_ARCHONLY_SUB_DIRS
		      |INCPUSH_CAN_RELOCATE);
#endif
#endif /* !PERL_IS_MINIPERL */

    if (!TAINTING_get) {
        const char * const unsafe = PerlEnv_getenv("PERL_USE_UNSAFE_INC");
        if (unsafe && strEQ(unsafe, "1"))
          incpush(aTHX_ STR_WITH_LEN("."), 0);
#ifdef PERL_IS_MINIPERL
        else
          incpush(aTHX_ STR_WITH_LEN("."), 0);
#endif
    }
    /* cpanel-perl does not support . in @INC */
}

static void validate_suid(pTHX_ PerlIO *rsfp)
{
    const Uid_t  my_uid = PerlProc_getuid();
    const Uid_t my_euid = PerlProc_geteuid();
    const Gid_t  my_gid = PerlProc_getgid();
    const Gid_t my_egid = PerlProc_getegid();

    if (my_euid != my_uid || my_egid != my_gid) {	/* (suidperl doesn't exist, in fact) */
	dVAR;
        int fd = PerlIO_fileno(rsfp);
        Stat_t statbuf;
        if (fd < 0 || PerlLIO_fstat(fd, &statbuf) < 0) { /* may be either wrapped or real suid */
            Perl_croak_nocontext( "Illegal suidscript");
        }
        if ((my_euid != my_uid && my_euid == statbuf.st_uid && statbuf.st_mode & S_ISUID)
            ||
            (my_egid != my_gid && my_egid == statbuf.st_gid && statbuf.st_mode & S_ISGID)
            )
	    if (!PL_do_undump)
		Perl_croak(aTHX_ "YOU HAVEN'T DISABLED SET-ID SCRIPTS IN THE KERNEL YET!\n\
FIX YOUR KERNEL, PUT A C WRAPPER AROUND THIS SCRIPT, OR USE -u AND UNDUMP!\n");
	/* not set-id, must be wrapped */
    }
}

static void find_beginning(pTHX_ SV* linestr_sv, PerlIO *rsfp)
{
    const char *s;
    const char *s2;

    /* skip forward in input to the real script? */

    do {
	if ((s = sv_gets(linestr_sv, rsfp, 0)) == NULL)
	    Perl_croak(aTHX_ "No Perl script found in input\n");
	s2 = s;
    } while (!(*s == '#' && s[1] == '!' && ((s = instr(s,"perl")) || (s = instr(s2,"PERL")))));
    PerlIO_ungetc(rsfp, '\n');		/* to keep line count right */
    while (*s && !(isSPACE (*s) || *s == '#')) s++;
    s2 = s;
    while (*s == ' ' || *s == '\t') s++;
    if (*s++ == '-') {
	while (isDIGIT(s2[-1]) || s2[-1] == '-' || s2[-1] == '.'
	       || s2[-1] == '_') s2--;
	if (strnEQ(s2-4,"perl",4))
	    while ((s = moreswitches(s)))
		;
    }
}

static void init_predump_symbols(pTHX)
{
    GV *tmpgv;
    IO *io;

    sv_setpvs(get_sv("\"", GV_ADD), " ");
    PL_ofsgv = (GV*)SvREFCNT_inc(gv_fetchpvs(",", GV_ADD|GV_NOTQUAL, SVt_PV));


    /* Historically, PVIOs were blessed into IO::Handle, unless
       FileHandle was loaded, in which case they were blessed into
       that. Action at a distance.
       However, if we simply bless into IO::Handle, we break code
       that assumes that PVIOs will have (among others) a seek
       method. IO::File inherits from IO::Handle and IO::Seekable,
       and provides the needed methods. But if we simply bless into
       it, then we break code that assumed that by loading
       IO::Handle, *it* would work.
       So a compromise is to set up the correct @IO::File::ISA,
       so that code that does C<use IO::Handle>; will still work.
    */
		   
    Perl_populate_isa(aTHX_ STR_WITH_LEN("IO::File::ISA"),
		      STR_WITH_LEN("IO::Handle::"),
		      STR_WITH_LEN("IO::Seekable::"),
		      STR_WITH_LEN("Exporter::"),
		      NULL);

    PL_stdingv = gv_fetchpvs("STDIN", GV_ADD|GV_NOTQUAL, SVt_PVIO);
    GvMULTI_on(PL_stdingv);
    io = GvIOp(PL_stdingv);
    IoTYPE(io) = IoTYPE_RDONLY;
    IoIFP(io) = PerlIO_stdin();
    tmpgv = gv_fetchpvs("stdin", GV_ADD|GV_NOTQUAL, SVt_PV);
    GvMULTI_on(tmpgv);
    GvIOp(tmpgv) = MUTABLE_IO(SvREFCNT_inc_simple(io));

    tmpgv = gv_fetchpvs("STDOUT", GV_ADD|GV_NOTQUAL, SVt_PVIO);
    GvMULTI_on(tmpgv);
    io = GvIOp(tmpgv);
    IoTYPE(io) = IoTYPE_WRONLY;
    IoOFP(io) = IoIFP(io) = PerlIO_stdout();
    setdefout(tmpgv);
    tmpgv = gv_fetchpvs("stdout", GV_ADD|GV_NOTQUAL, SVt_PV);
    GvMULTI_on(tmpgv);
    GvIOp(tmpgv) = MUTABLE_IO(SvREFCNT_inc_simple(io));

    PL_stderrgv = gv_fetchpvs("STDERR", GV_ADD|GV_NOTQUAL, SVt_PVIO);
    GvMULTI_on(PL_stderrgv);
    io = GvIOp(PL_stderrgv);
    IoTYPE(io) = IoTYPE_WRONLY;
    IoOFP(io) = IoIFP(io) = PerlIO_stderr();
    tmpgv = gv_fetchpvs("stderr", GV_ADD|GV_NOTQUAL, SVt_PV);
    GvMULTI_on(tmpgv);
    GvIOp(tmpgv) = MUTABLE_IO(SvREFCNT_inc_simple(io));

    PL_statname = newSVpvs("");		/* last filename we did stat on */
}

#ifndef PERLLIB_MANGLE
#  define PERLLIB_MANGLE(s,n) (s)
#endif

static SV * mayberelocate(pTHX_ const char *const dir, STRLEN len, U32 flags)
{
    const U8 canrelocate = (U8)flags & INCPUSH_CAN_RELOCATE;
    SV *libdir;

    assert(len > 0);

    /* I am not convinced that this is valid when PERLLIB_MANGLE is
       defined to so something (in os2/os2.c), but the code has been
       this way, ignoring any possible changed of length, since
       760ac839baf413929cd31cc32ffd6dba6b781a81 (5.003_02) so I'll leave
       it be.  */
    libdir = newSVpvn(PERLLIB_MANGLE(dir, len), len);

#ifdef VMS
    {
	char *unix;

	if ((unix = tounixspec_ts(SvPV(libdir,len),NULL)) != NULL) {
	    len = strlen(unix);
	    while (len > 1 && unix[len-1] == '/') len--;  /* Cosmetic */
	    sv_usepvn(libdir,unix,len);
	}
	else
	    PerlIO_printf(Perl_error_log,
		          "Failed to unixify @INC element \"%s\"\n",
			  SvPV_nolen_const(libdir));
    }
#endif

	/* Do the if() outside the #ifdef to avoid warnings about an unused
	   parameter.  */
	if (canrelocate) {
#ifdef PERL_RELOCATABLE_INC
	/*
	 * Relocatable include entries are marked with a leading .../
	 *
	 * The algorithm is
	 * 0: Remove that leading ".../"
	 * 1: Remove trailing executable name (anything after the last '/')
	 *    from the perl path to give a perl prefix
	 * Then
	 * While the @INC element starts "../" and the prefix ends with a real
	 * directory (ie not . or ..) chop that real directory off the prefix
	 * and the leading "../" from the @INC element. ie a logical "../"
	 * cleanup
	 * Finally concatenate the prefix and the remainder of the @INC element
	 * The intent is that /usr/local/bin/perl and .../../lib/perl5
	 * generates /usr/local/lib/perl5
	 */
	    const char *libpath = SvPVX(libdir);
	    STRLEN libpath_len = SvCUR(libdir);
	    if (libpath_len >= 4 && memEQ (libpath, ".../", 4)) {
		/* Game on!  */
		SV * const caret_X = get_sv("\030", 0);
		/* Going to use the SV just as a scratch buffer holding a C
		   string:  */
		SV *prefix_sv;
		char *prefix;
		char *lastslash;

		/* $^X is *the* source of taint if tainting is on, hence
		   SvPOK() won't be true.  */
		assert(caret_X);
		assert(SvPOKp(caret_X));
		prefix_sv = newSVpvn_flags(SvPVX(caret_X), SvCUR(caret_X),
					   SvUTF8(caret_X));
		/* Firstly take off the leading .../
		   If all else fail we'll do the paths relative to the current
		   directory.  */
		sv_chop(libdir, libpath + 4);
		/* Don't use SvPV as we're intentionally bypassing taining,
		   mortal copies that the mg_get of tainting creates, and
		   corruption that seems to come via the save stack.
		   I guess that the save stack isn't correctly set up yet.  */
		libpath = SvPVX(libdir);
		libpath_len = SvCUR(libdir);

		/* This would work more efficiently with memrchr, but as it's
		   only a GNU extension we'd need to probe for it and
		   implement our own. Not hard, but maybe not worth it?  */

		prefix = SvPVX(prefix_sv);
		lastslash = strrchr(prefix, '/');

		/* First time in with the *lastslash = '\0' we just wipe off
		   the trailing /perl from (say) /usr/foo/bin/perl
		*/
		if (lastslash) {
		    SV *tempsv;
		    while ((*lastslash = '\0'), /* Do that, come what may.  */
			   (libpath_len >= 3 && memEQ(libpath, "../", 3)
			    && (lastslash = strrchr(prefix, '/')))) {
			if (lastslash[1] == '\0'
			    || (lastslash[1] == '.'
				&& (lastslash[2] == '/' /* ends "/."  */
				    || (lastslash[2] == '/'
					&& lastslash[3] == '/' /* or "/.."  */
					)))) {
			    /* Prefix ends "/" or "/." or "/..", any of which
			       are fishy, so don't do any more logical cleanup.
			    */
			    break;
			}
			/* Remove leading "../" from path  */
			libpath += 3;
			libpath_len -= 3;
			/* Next iteration round the loop removes the last
			   directory name from prefix by writing a '\0' in
			   the while clause.  */
		    }
		    /* prefix has been terminated with a '\0' to the correct
		       length. libpath points somewhere into the libdir SV.
		       We need to join the 2 with '/' and drop the result into
		       libdir.  */
		    tempsv = Perl_newSVpvf(aTHX_ "%s/%s", prefix, libpath);
		    SvREFCNT_dec(libdir);
		    /* And this is the new libdir.  */
		    libdir = tempsv;
		    if (TAINTING_get &&
			(PerlProc_getuid() != PerlProc_geteuid() ||
			 PerlProc_getgid() != PerlProc_getegid())) {
			/* Need to taint relocated paths if running set ID  */
			SvTAINTED_on(libdir);
		    }
		}
		SvREFCNT_dec(prefix_sv);
	    }
#endif
	}
    return libdir;
}

static SV * S_incpush_if_exists(pTHX_ AV *const av, SV *dir, SV *const stem)
{
    Stat_t tmpstatbuf;

    if (PerlLIO_stat(SvPVX_const(dir), &tmpstatbuf) >= 0 &&
	S_ISDIR(tmpstatbuf.st_mode)) {
	av_push(av, dir);
	dir = newSVsv(stem);
    } else {
	/* Truncate dir back to stem.  */
	SvCUR_set(dir, SvCUR(stem));
    }
    return dir;
}

#define PERLLIB_SEP ':'


static void S_incpush_use_sep(pTHX_ const char *p, STRLEN len, U32 flags)
{
    const char *s;
    const char *end;
    /* This logic has been broken out from S_incpush(). It may be possible to
       simplify it.  */

    /* perl compiled with -DPERL_RELOCATABLE_INCPUSH will ignore the len
     * argument to incpush_use_sep.  This allows creation of relocatable
     * Perl distributions that patch the binary at install time.  Those
     * distributions will have to provide their own relocation tools; this
     * is not a feature otherwise supported by core Perl.
     */
#ifndef PERL_RELOCATABLE_INCPUSH
    if (!len)
#endif
	len = strlen(p);

    end = p + len;

    /* Break at all separators */
    while ((s = (const char*)memchr(p, PERLLIB_SEP, end - p))) {
	if (s == p) {
	    /* skip any consecutive separators */

	    /* Uncomment the next line for PATH semantics */
	    /* But you'll need to write tests */
	    /* av_push(GvAVn(PL_incgv), newSVpvs(".")); */
	} else {
	    incpush(p, (STRLEN)(s - p), flags);
	}
	p = s + 1;
    }
    if (p != end)
	incpush(p, (STRLEN)(end - p), flags);

}

static void
S_Internals_V(pTHX_ CV *cv)
{
    dXSARGS;
#ifdef LOCAL_PATCH_COUNT
    const int local_patch_count = LOCAL_PATCH_COUNT;
#else
    const int local_patch_count = 0;
#endif
    const int entries = 3 + local_patch_count;
    int i;
    static const char non_bincompat_options[] = 
#  ifdef DEBUGGING
			     " DEBUGGING"
#  endif
#  ifdef NO_MATHOMS
			     " NO_MATHOMS"
#  endif
#  ifdef NO_HASH_SEED
			     " NO_HASH_SEED"
#  endif
#  ifdef NO_TAINT_SUPPORT
			     " NO_TAINT_SUPPORT"
#  endif
#  ifdef PERL_BOOL_AS_CHAR
			     " PERL_BOOL_AS_CHAR"
#  endif
#  ifdef PERL_COPY_ON_WRITE
			     " PERL_COPY_ON_WRITE"
#  endif
#  ifdef PERL_DISABLE_PMC
			     " PERL_DISABLE_PMC"
#  endif
#  ifdef PERL_DONT_CREATE_GVSV
			     " PERL_DONT_CREATE_GVSV"
#  endif
#  ifdef PERL_EXTERNAL_GLOB
			     " PERL_EXTERNAL_GLOB"
#  endif
#  ifdef PERL_HASH_FUNC_SIPHASH
			     " PERL_HASH_FUNC_SIPHASH"
#  endif
#  ifdef PERL_HASH_FUNC_SDBM
			     " PERL_HASH_FUNC_SDBM"
#  endif
#  ifdef PERL_HASH_FUNC_DJB2
			     " PERL_HASH_FUNC_DJB2"
#  endif
#  ifdef PERL_HASH_FUNC_SUPERFAST
			     " PERL_HASH_FUNC_SUPERFAST"
#  endif
#  ifdef PERL_HASH_FUNC_MURMUR3
			     " PERL_HASH_FUNC_MURMUR3"
#  endif
#  ifdef PERL_HASH_FUNC_ONE_AT_A_TIME
			     " PERL_HASH_FUNC_ONE_AT_A_TIME"
#  endif
#  ifdef PERL_HASH_FUNC_ONE_AT_A_TIME_HARD
			     " PERL_HASH_FUNC_ONE_AT_A_TIME_HARD"
#  endif
#  ifdef PERL_HASH_FUNC_ONE_AT_A_TIME_OLD
			     " PERL_HASH_FUNC_ONE_AT_A_TIME_OLD"
#  endif
#  ifdef PERL_IS_MINIPERL
			     " PERL_IS_MINIPERL"
#  endif
#  ifdef PERL_MALLOC_WRAP
			     " PERL_MALLOC_WRAP"
#  endif
#  ifdef PERL_MEM_LOG
			     " PERL_MEM_LOG"
#  endif
#  ifdef PERL_MEM_LOG_NOIMPL
			     " PERL_MEM_LOG_NOIMPL"
#  endif
#  ifdef PERL_PERTURB_KEYS_DETERMINISTIC
			     " PERL_PERTURB_KEYS_DETERMINISTIC"
#  endif
#  ifdef PERL_PERTURB_KEYS_DISABLED
			     " PERL_PERTURB_KEYS_DISABLED"
#  endif
#  ifdef PERL_PERTURB_KEYS_RANDOM
			     " PERL_PERTURB_KEYS_RANDOM"
#  endif
#  ifdef PERL_PRESERVE_IVUV
			     " PERL_PRESERVE_IVUV"
#  endif
#  ifdef PERL_RELOCATABLE_INCPUSH
			     " PERL_RELOCATABLE_INCPUSH"
#  endif
#  ifdef PERL_USE_DEVEL
			     " PERL_USE_DEVEL"
#  endif
#  ifdef PERL_USE_SAFE_PUTENV
			     " PERL_USE_SAFE_PUTENV"
#  endif
#  ifdef SILENT_NO_TAINT_SUPPORT
                             " SILENT_NO_TAINT_SUPPORT"
#  endif
#  ifdef UNLINK_ALL_VERSIONS
			     " UNLINK_ALL_VERSIONS"
#  endif
#  ifdef USE_ATTRIBUTES_FOR_PERLIO
			     " USE_ATTRIBUTES_FOR_PERLIO"
#  endif
#  ifdef USE_FAST_STDIO
			     " USE_FAST_STDIO"
#  endif	       
#  ifdef USE_HASH_SEED_EXPLICIT
			     " USE_HASH_SEED_EXPLICIT"
#  endif
#  ifdef USE_LOCALE
			     " USE_LOCALE"
#  endif
#  ifdef USE_LOCALE_CTYPE
			     " USE_LOCALE_CTYPE"
#  endif
#  ifdef WIN32_NO_REGISTRY
			     " USE_NO_REGISTRY"
#  endif
#  ifdef USE_PERL_ATOF
			     " USE_PERL_ATOF"
#  endif	       
	;
    PERL_UNUSED_ARG(cv);
    PERL_UNUSED_VAR(items);

    EXTEND(SP, entries);

    PUSHs(sv_2mortal(newSVpv(PL_bincompat_options, 0)));
    PUSHs(Perl_newSVpvn_flags(aTHX_ non_bincompat_options,
			      sizeof(non_bincompat_options) - 1, SVs_TEMP));

#ifndef PERL_BUILD_DATE
#  ifdef __DATE__
#    ifdef __TIME__
#      define PERL_BUILD_DATE __DATE__ " " __TIME__
#    else
#      define PERL_BUILD_DATE __DATE__
#    endif
#  endif
#endif

#ifdef PERL_BUILD_DATE
    PUSHs(Perl_newSVpvn_flags(aTHX_
			      STR_WITH_LEN("Compiled at " PERL_BUILD_DATE),
			      SVs_TEMP));
#else
    PUSHs(&PL_sv_undef);
#endif

    for (i = 1; i <= local_patch_count; i++) {
	/* This will be an undef, if PL_localpatches[i] is NULL.  */
	PUSHs(sv_2mortal(newSVpv(PL_localpatches[i], 0)));
    }

    XSRETURN(entries);
}