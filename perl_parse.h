
void bc_parse_body(char **env, XSINIT_t xsinit);
static void init_postdump_symbols(pTHX_ int argc, char **argv, char **env);
static void init_predump_symbols(pTHX);
#define NEVER Perl_croak_nocontext("Shouldn't get here\n\n");

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
	const UV aligned = (mask < ~(UV)0) && ((PTR2UV(argv[0]) & mask) == PTR2UV(argv[0]));

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

	 /* Can we grab env area too to be used as the area for $0? */
	if (s && PL_origenviron && !PL_use_safe_putenv) {
        if ((PL_origenviron[0] == s + 1) || (aligned && (PL_origenviron[0] > s && PL_origenviron[0] <= INT2PTR(char *, PTR2UV(s + PTRSIZE) & mask))) ) {
            s = PL_origenviron[0];
            while (*s) s++;
            my_setenv("NoNe  SuCh", NULL);
            /* Force copy of environment. */
            for (i = 1; PL_origenviron[i]; i++) {
                if (PL_origenviron[i] == s + 1 || (aligned && (PL_origenviron[i] >  s && PL_origenviron[i] <= INT2PTR(char *, PTR2UV(s + PTRSIZE) & mask))) ) {
                    s = PL_origenviron[i];
                    while (*s) s++;
                }
                else
                    break;
            }
        }
	}

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
    int argc = PL_origargc;
    char **argv = PL_origargv;
    const char *scriptname = NULL;
    SV *linestr_sv = NULL;
    U32 lex_start_flags = 0;

    PERL_SET_PHASE(PERL_PHASE_START);

    /* init_main_stash(); PL_defstash setup */
    PL_curstash = PL_defstash;

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

    /* init_perllib(); We hard code @INC on our own.*/

	{
	    Sighandler_t sigstate = rsignal_state(SIGCHLD);
	    if (sigstate == (Sighandler_t) SIG_IGN) {
    		Perl_ck_warner(aTHX_ packWARN(WARN_SIGNAL),
			       "Can't ignore signal CHLD, forcing to default");
    		(void)rsignal(SIGCHLD, (Sighandler_t)SIG_DFL);
	    }
	}

    PL_main_cv = PL_compcv = MUTABLE_CV(newSV_type(SVt_PVCV));
    CvUNIQUE_on(PL_compcv);

    CvPADLIST_set(PL_compcv, pad_new(0));

    PL_isarev = newHV();

    boot_core_PerlIO();
    boot_core_UNIVERSAL();
    boot_core_mro();

    if (xsinit)
        (*xsinit)(aTHX);	/* in case linked C routines want magical variables */

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
    if (PL_unicode) {
	 /* Requires init_predump_symbols(). */
        if (!(PL_unicode & PERL_UNICODE_LOCALE_FLAG) || PL_utf8locale) {
            IO* io;
            PerlIO* fp;
            SV* sv;
  
            /* Turn on UTF-8-ness on STDIN, STDOUT, STDERR
             * and the default open disciplines. */
            if ((PL_unicode & PERL_UNICODE_STDIN_FLAG) && PL_stdingv  && (io = GvIO(PL_stdingv)) && (fp = IoIFP(io)))
                PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");
            
            if ((PL_unicode & PERL_UNICODE_STDOUT_FLAG) && PL_defoutgv && (io = GvIO(PL_defoutgv)) && (fp = IoOFP(io)))
                PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");

            if ((PL_unicode & PERL_UNICODE_STDERR_FLAG) && PL_stderrgv && (io = GvIO(PL_stderrgv)) && (fp = IoOFP(io)))
                PerlIO_binmode(aTHX_ fp, IoTYPE(io), 0, ":utf8");

            if ((PL_unicode & PERL_UNICODE_INOUT_FLAG) && (sv = GvSV(gv_fetchpvs("\017PEN", GV_ADD|GV_NOTQUAL, SVt_PV)))) {
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


    lex_start(linestr_sv, NULL, lex_start_flags);
    SvREFCNT_dec(linestr_sv);

    PL_subname = newSVpvs("main");

    /* now parse the script */

    SETERRNO(0,SS_NORMAL);
    CopLINE_set(PL_curcop, 0);
    PL_defstash = PL_curstash;
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

    ENTER;
    PL_restartjmpenv = NULL;
    PL_restartop = 0;
}

STATIC void init_postdump_symbols(pTHX_ int argc, char **argv, char **env)
{
    GV* tmpgv;

    /* Set PL_toptarget to a PVIV set to "" */
    PL_toptarget = newSV_type(SVt_PVIV);
    sv_setpvs(PL_toptarget, "");

    /* Set PL_bodytarget and PL_formtarget to a PVIV set to "" */
    PL_bodytarget = newSV_type(SVt_PVIV);
    sv_setpvs(PL_bodytarget, "");
    PL_formtarget = PL_bodytarget;

    TAINT;

    /* @ARGV (PL_argvgv) is setup here. */
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

    	/* Note that if the supplied env parameter is actually a copy
    	   of the global environ then it may now point to free'd memory
    	   if the environment has been modified since. To avoid this
    	   problem we treat env==NULL as meaning 'use the default'
    	*/
    	if (!env)
    	    env = environ;
    	env_is_not_environ = env != environ;
    	if (env_is_not_environ) {
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
                    else
                        sv = newSVpv(s+1, 0);
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
    }
    TAINT_NOT;

    /* touch @F array to prevent spurious warnings 20020415 MJD */
    /* B::C doesn't support perl -a so this is dead code. */
    if (PL_minus_a) {
      (void) get_av("main::F", GV_ADD | GV_ADDMULTI);
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
