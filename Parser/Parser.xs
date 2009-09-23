#/* Verilog.xs -- Verilog Booter  -*- C++ -*-
#*********************************************************************
#*
#* DESCRIPTION: Verilog::Parser Perl XS interface
#*
#* Author: Wilson Snyder <wsnyder@wsnyder.org>
#*
#* Code available from: http://www.veripool.org/
#*
#*********************************************************************
#*
#* Copyright 2000-2009 by Wilson Snyder.  This program is free software;
#* you can redistribute it and/or modify it under the terms of either the GNU
#* Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.
#*
#* This program is distributed in the hope that it will be useful,
#* but WITHOUT ANY WARRANTY; without even the implied warranty of
#* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#* GNU General Public License for more details.
#*
#* You should have received a copy of the Perl Artistic License
#* along with this module; see the file COPYING.  If not, see
#* www.cpan.org
#*
#***********************************************************************
#* Note with C++ XS libraries, the CLASS parameter is implied...
#***********************************************************************/

/* Mine: */
#include "VParse.h"
#include "VSymTable.h"
#include "VAst.h"

/* Perl */
extern "C" {
# include "EXTERN.h"
# include "perl.h"
# include "XSUB.h"
}

#ifdef open
# undef open	/* Perl 64 bit on solaris has a nasty hack that redefines open */
#endif

#//**********************************************************************
#// Parseressor derived classes, so we can override the callbacks to call perl.

class VParserXs : public VParse {
public:
    SV*		m_self;	// Class called from
    VFileLine*	m_cbFilelinep;	///< Last callback's starting point

    // Callback enables
    bool	m_useVars;	///< Need pin callbacks

    VFileLine* cbFilelinep() const { return m_cbFilelinep; }
    void cbFileline(const string& filename, int lineno) { m_cbFilelinep = m_cbFilelinep->create(filename, lineno); }
    void cbFileline(VFileLine* filelinep) { m_cbFilelinep = filelinep; }

    VParserXs(VFileLine* filelinep, av* symsp, bool sigparser, bool useUnreadback
	      , bool useVars)
	: VParse(filelinep, symsp, sigparser, useUnreadback)
	, m_cbFilelinep(filelinep)
	, m_useVars(useVars)
	{}
    virtual ~VParserXs() {}

    // CALLBACKGEN_H_VIRTUAL
    // CALLBACKGEN_GENERATED_BEGIN - GENERATED AUTOMATICALLY by callbackgen
    // Verilog::Parser Callback methods
    virtual void attributeCb(VFileLine* fl, const string& text);
    virtual void commentCb(VFileLine* fl, const string& text);
    virtual void endparseCb(VFileLine* fl, const string& text);
    virtual void keywordCb(VFileLine* fl, const string& text);
    virtual void numberCb(VFileLine* fl, const string& text);
    virtual void operatorCb(VFileLine* fl, const string& text);
    virtual void preprocCb(VFileLine* fl, const string& text);
    virtual void stringCb(VFileLine* fl, const string& text);
    virtual void symbolCb(VFileLine* fl, const string& text);
    virtual void sysfuncCb(VFileLine* fl, const string& text);
    // Verilog::SigParser Callback methods
    virtual void endcellCb(VFileLine* fl, const string& kwd);
    virtual void endinterfaceCb(VFileLine* fl, const string& kwd);
    virtual void endmoduleCb(VFileLine* fl, const string& kwd);
    virtual void endpackageCb(VFileLine* fl, const string& kwd);
    virtual void endprogramCb(VFileLine* fl, const string& kwd);
    virtual void endtaskfuncCb(VFileLine* fl, const string& kwd);
    virtual void functionCb(VFileLine* fl, const string& kwd, const string& name, const string& data_type);
    virtual void importCb(VFileLine* fl, const string& package, const string& id);
    virtual void instantCb(VFileLine* fl, const string& mod, const string& cell, const string& range);
    virtual void interfaceCb(VFileLine* fl, const string& kwd, const string& name);
    virtual void moduleCb(VFileLine* fl, const string& kwd, const string& name, bool, bool celldefine);
    virtual void packageCb(VFileLine* fl, const string& kwd, const string& name);
    virtual void parampinCb(VFileLine* fl, const string& name, const string& conn, int index);
    virtual void pinCb(VFileLine* fl, const string& name, const string& conn, int index);
    virtual void portCb(VFileLine* fl, const string& name, const string& objof, const string& direction, const string& data_type
	, const string& array, int index);
    virtual void programCb(VFileLine* fl, const string& kwd, const string& name);
    virtual void taskCb(VFileLine* fl, const string& kwd, const string& name);
    virtual void varCb(VFileLine* fl, const string& kwd, const string& name, const string& objof, const string& net
	, const string& data_type, const string& array, const string& value);
    // CALLBACKGEN_GENERATED_END - GENERATED AUTOMATICALLY by callbackgen

    void call(string* rtnStrp, int params, const char* method, ...);
};

class VFileLineParseXs : public VFileLine {
    VParserXs*	m_vParserp;		// Parser handling the errors
public:
    VFileLineParseXs(int called_only_for_default) : VFileLine(called_only_for_default) {}
    virtual ~VFileLineParseXs() { }
    virtual VFileLine* create(const string filename, int lineno);
    virtual void error(const string msg);	// Report a error at given location
    void setParser(VParserXs* pp) { m_vParserp=pp; }
};

#//**********************************************************************
#// Overrides error handling virtual functions to invoke callbacks

VFileLine* VFileLineParseXs::create(const string filename, int lineno) {
    VFileLineParseXs* filelp = new VFileLineParseXs(true);
    filelp->init(filename, lineno);
    filelp->m_vParserp = m_vParserp;
    return filelp;
}

void VFileLineParseXs::error(string msg) {
    static string holdmsg; holdmsg = msg;
    m_vParserp->cbFileline(this);
    // Call always, not just if callbacks enabled
    m_vParserp->call(NULL, 1,"error",holdmsg.c_str());
}

#//**********************************************************************
#// Overrides of virtual functions to invoke callbacks

#include "Parser_callbackgen.cpp"

#//**********************************************************************
#// Manually created callbacks

#//**********************************************************************
#// General callback invoker

void VParserXs::call (
    string* rtnStrp,	/* If non-null, load return value here */
    int params,		/* Number of parameters */
    const char* method,	/* Name of method to call */
    ...)		/* Arguments to pass to method's @_ */
{
    // Call $perlself->method (passedparam1, parsedparam2)
    if (debug()) cout << "CALLBACK "<<method<<endl;
    va_list ap;
    va_start(ap, method);
    {
	dSP;				/* Initialize stack pointer */
	ENTER;				/* everything created after here */
	SAVETMPS;			/* ...is a temporary variable. */
	PUSHMARK(SP);			/* remember the stack pointer */
	XPUSHs(m_self);			/* $self-> */

	while (params--) {
	    char *text;
	    SV *sv;
	    text = va_arg(ap, char *);
	    if (text) {
		sv = newSVpv (text, 0);
	    } else {
		sv = &PL_sv_undef;
	    }
	    XPUSHs(sv);			/* token */
	}

	PUTBACK;			/* make local stack pointer global */

	if (rtnStrp) {
	    int rtnCount = perl_call_method ((char*)method, G_SCALAR);
	    SPAGAIN;			/* refresh stack pointer */
	    if (rtnCount > 0) {
		SV* sv = POPs;
		//printf("RTN %ld %d %s\n", SvTYPE(sv),SvTRUE(sv),SvPV_nolen(sv));
#ifdef SvPV_nolen	// Perl 5.6 and later
		*rtnStrp = SvPV_nolen(sv);
#else
		*rtnStrp = SvPV(sv,PL_na);
#endif
	    }
	    PUTBACK;
	} else {
	    perl_call_method ((char*)method, G_DISCARD | G_VOID);
	}

	FREETMPS;			/* free that return value */
	LEAVE;				/* ...and the XPUSHed "mortal" args.*/
    }
    va_end(ap);
}

#//**********************************************************************

MODULE = Verilog::Parser  PACKAGE = Verilog::Parser

#//**********************************************************************
#// self->_new (class, sigparser)

static VParserXs *
VParserXs::_new (SV* SELF, AV* symsp, bool sigparser, bool useUnreadback, bool useVars)
PROTOTYPE: $$$$$
CODE:
{
    if (CLASS) {}  /* Prevent unused warning */
    VFileLineParseXs* filelinep = new VFileLineParseXs(1/*ok,for initial*/);
    VParserXs* parserp = new VParserXs(filelinep, symsp, sigparser, useUnreadback, useVars);
    filelinep->setParser(parserp);
    parserp->m_self = newSVsv(SELF);
    RETVAL = parserp;
}
OUTPUT: RETVAL

#//**********************************************************************
#// self->_DESTROY()

void
VParserXs::_DESTROY()
PROTOTYPE: $
CODE:
{
    delete THIS;
}

#//**********************************************************************
#// self->debug(level)

void
VParserXs::_debug (level)
int level
PROTOTYPE: $$
CODE:
{
    THIS->debug(level);
    VAstEnt::debug(level);
}

#//**********************************************************************
#// self->_callback_enable(flag)
#// Turn off callbacks during std:: parsing

void
VParserXs::_callback_enable (flag)
bool flag
PROTOTYPE: $$
CODE:
{
    THIS->callbackEnable(flag);
}

#//**********************************************************************
#// self->eof()

void
VParserXs::eof ()
PROTOTYPE: $
CODE:
{
    THIS->setEof();
}
#//**********************************************************************
#// self->filename([setit])

const char *
VParserXs::filename (const char* flagp="")
PROTOTYPE: $;$
CODE:
{
    if (!THIS) XSRETURN_UNDEF;
    if (items > 1) {
	THIS->inFileline(flagp, THIS->inFilelinep()->lineno());
	THIS->cbFileline(flagp, THIS->inFilelinep()->lineno());
    }
    RETVAL = THIS->cbFilelinep()->filename().c_str();
}
OUTPUT: RETVAL

#//**********************************************************************
#// self->language()

void
VParserXs::language (valuep)
const char* valuep
PROTOTYPE: $$
CODE:
{
    if (items > 1) {
        THIS->language(valuep);
    }
}

#//**********************************************************************
#// self->lineno([setit])

int
VParserXs::lineno (int flag=0)
PROTOTYPE: $;$
CODE:
{
    if (!THIS) XSRETURN_UNDEF;
    if (items > 1) {
	THIS->inFileline(THIS->inFilelinep()->filename(), flag);
	THIS->cbFileline(THIS->inFilelinep()->filename(), flag);
    }
    RETVAL = (THIS->cbFilelinep()->lineno());
}
OUTPUT: RETVAL

#//**********************************************************************
#// self->parse()

void
VParserXs::parse (const char* textp)
PROTOTYPE: $$
CODE:
{
    THIS->parse(textp);
}

#//**********************************************************************
#// self->selftest()

void
VParserXs::selftest ()
PROTOTYPE: $
CODE:
{
    VSymStack::selftest();
}

#//**********************************************************************
#// self->unreadback()

SV*
VParserXs::unreadback (const char* flagp="")
PROTOTYPE: $;$
CODE:
{
    if (!THIS) XSRETURN_UNDEF;
    // Set RETVAL to a SV before we replace with the new value, and c_str may change
    RETVAL = newSVpv(THIS->unreadback().c_str(), THIS->unreadback().length());
    if (items > 1) {
	THIS->unreadback(flagp);
    }
}
OUTPUT: RETVAL

#//**********************************************************************
#// self->unreadbackCat()

void
VParserXs::unreadbackCat (SV* textsvp)
PROTOTYPE: $$
CODE:
{
    if (!THIS) XSRETURN_UNDEF;
    STRLEN textlen;
    const char* textp = SvPV(textsvp, textlen);
    THIS->unreadbackCat(textp, textlen);
}
