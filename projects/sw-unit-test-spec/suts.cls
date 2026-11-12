% =============================================================================
%  suts.cls -- Software Unit Test Specification (template / layout)
%
%  Structure follows ISO/IEC/IEEE 29119-3 (test design / test case spec) and
%  covers the work products expected by Automotive SPICE SWE.4 (unit
%  verification) and ISO 26262-6 clause 9 (software unit verification).
%
%  This file holds ALL formatting. Unit-specific content lives in content/*.tex
%  and uses only the input commands defined below (no tables, no &, no \\).
%  See README.md for the full command reference.
%
%  Class options are passed on to `article` (e.g. 10pt, letterpaper).
% =============================================================================
\NeedsTeXFormat{LaTeX2e}[2022-06-01]
\ProvidesClass{suts}[2026/11/04 v2.0 Software Unit Test Specification]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[11pt,a4paper]{article}

% ---------------------------------------------------------------- packages ---
\RequirePackage[T1]{fontenc}
\RequirePackage{lmodern}
\RequirePackage{tikz}
\usetikzlibrary{arrows.meta,positioning,fit,calc,shapes.geometric}
\RequirePackage{microtype}
\DisableLigatures[-]{family=tt*}      % --coverage stays two hyphens in code
\RequirePackage[margin=2.2cm,headheight=28pt]{geometry}
\RequirePackage{xcolor}
\RequirePackage{booktabs}
\RequirePackage{tabularx}
\RequirePackage{xltabular}             % tabularx that breaks across pages
\RequirePackage{array}
\RequirePackage{enumitem}
\RequirePackage{fancyhdr}
\RequirePackage{lastpage}
\RequirePackage{amsmath}               % formulas in free text: align, cases, ...
\RequirePackage{amssymb}
\RequirePackage[most]{tcolorbox}
\RequirePackage[export]{adjustbox}      % diagrams shrink to the text width if needed
\RequirePackage{needspace}              % keep headings with their tables
\RequirePackage{fancyvrb}               % FreeText: body copied verbatim to a file
\RequirePackage{graphicx}               % search paths: see \LoadContent
\RequirePackage[hidelinks]{hyperref}
% underscore LAST: its active _ breaks older packages loaded after it
% (pgf < 3.1.11, older fancyvrb on TeX Live 2022)
\RequirePackage[strings,nohyphen]{underscore} % plain _ in text: unit_name, Unit_Init()

% ---------------------------------------------------------------- styling ---
\definecolor{accent}{HTML}{1F4E79}
\definecolor{tcbg}{HTML}{F4F7FB}
\definecolor{phgray}{HTML}{8A8A8A}
\definecolor{warn}{HTML}{B00020}

\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}
\renewcommand{\arraystretch}{1.25}
\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}}
\newcolumntype{Y}{>{\raggedright\arraybackslash}X}

% helpers usable in content
\newcommand{\ph}[1]{\textcolor{phgray}{\textit{$\langle$#1$\rangle$}}} % placeholder
\newcommand{\code}[1]{\texttt{#1}}                                      % code / identifiers

\ExplSyntaxOn
% =============================================================================
%  Storage helpers
% =============================================================================
\prop_new:N \g__suts_meta_prop          % document / unit metadata
\prop_new:N \g__suts_text_prop          % prose blocks (scope, ...)
\cs_new_protected:Npn \__suts_new_list:n #1
  { \tl_new:c { g__suts_#1_tl } \int_new:c { g__suts_#1_int } }
\cs_new_protected:Npn \__suts_add:nn #1#2   % append a table row / list item
  { \tl_gput_right:cn { g__suts_#1_tl } {#2} \int_gincr:c { g__suts_#1_int } }
\cs_new:Npn \__suts_rows:n #1 { \tl_use:c { g__suts_#1_tl } }
\cs_new:Npn \__suts_count:n #1 { \int_use:c { g__suts_#1_int } }
\cs_new:Npn \__suts_if_list_empty:nTF #1
  { \int_compare:nNnTF { \int_use:c { g__suts_#1_int } } = 0 }
\clist_map_inline:nn
  { revisions, references, terms, interfaces, dependencies, methods,
    derivation, coverage, entry, exit, environment, deviations, covresults }
  { \__suts_new_list:n {#1} }

% metadata getter: value or grey placeholder
\cs_new:Npn \__suts_meta:n #1
  {
    \prop_if_in:NnTF \g__suts_meta_prop {#1}
      { \prop_item:Nn \g__suts_meta_prop {#1} } { \ph{#1} }
  }
\cs_new_protected:Npn \__suts_text:nn #1#2   % prose or fallback
  {
    \prop_get:NnNTF \g__suts_text_prop {#1} \l_tmpa_tl
      { \tl_use:N \l_tmpa_tl } {#2}
  }
% numbers get a percent sign: 100 -> 100 %, n.a. stays n.a.
\cs_new_protected:Npn \__suts_pct:n #1
  {
    \regex_match:nnTF { \A\s*[0-9]+(\.[0-9]+)?\s*\Z } {#1}
      { #1\,\% } {#1}
  }
\cs_new:Npn \__suts_none_row:n #1 { \multicolumn{#1}{@{}l}{\ph{none}} \\ }

% =============================================================================
%  Input commands: metadata  (content/metadata.tex)
% =============================================================================
\clist_map_inline:nn
  { DocTitle, DocID, DocVersion, DocStatus, DocDate, ProjectName, Company,
    Author, Reviewer, Approver, UnitName, UnitBaseline, IntegrityLevel,
    SourceFiles, Language, DesignReference }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { m }
      { \prop_gput:Nnn \g__suts_meta_prop {#1} {##1} }
  }
\prop_gput:Nnn \g__suts_meta_prop { DocTitle } { Software~Unit~Test~Specification }
\prop_gput:Nnn \g__suts_meta_prop { DocDate } { \today }
\prop_gput:Nnn \g__suts_meta_prop { DocStatus } { Draft }

% values for use in your own text
\NewDocumentCommand \TheUnit {} { \texttt{ \__suts_meta:n { UnitName } } }
\NewDocumentCommand \TheBaseline {} { \__suts_meta:n { UnitBaseline } }
\NewDocumentCommand \TheIntegrityLevel {} { \__suts_meta:n { IntegrityLevel } }

% \Revision{version}{date}{author}{change}
\NewDocumentCommand \Revision { m m m +m }
  { \__suts_add:nn { revisions } { #1 & #2 & #3 & #4 \\ } }

% =============================================================================
%  Input commands: introduction  (content/introduction.tex)
% =============================================================================
% Prose slots, each in two forms:
%   \Scope{text}                        plain text and paragraphs
%   \begin{Scope} ... \end{Scope}       any LaTeX (verbatim, listings, own
%                                       tables, %, &); \end{...} on its own line
% One macro serves both: called through \begin it starts the verbatim copy
% (see Free text below), otherwise it takes its argument. Given twice, the
% last one wins (warning).
\cs_new_protected:Npn \__suts_text_set:nn #1#2
  {
    \bool_lazy_and:nnF
      { \str_if_eq_p:Vn \g__suts_chapter_tl { testcases } }
      { ! \g__suts_scan_bool }     % testcases.tex is read twice
      {
        \prop_if_in:NnT \g__suts_text_prop {#1}
          { \msg_warning:nnn { suts } { duplicate-text } {#1} }
      }
    \prop_gput:Nnn \g__suts_text_prop {#1} {#2}
  }
\cs_generate_variant:Nn \__suts_text_set:nn { nx }
\msg_new:nnn { suts } { duplicate-text }
  { #1~given~more~than~once;~the~last~one~is~used. }
\clist_map_inline:nn
  { Purpose, Scope, UseCaseNote, FunctionalDescription, PassFailCriteria,
    ToolQualification, ResultsNote }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { }
      {
        \str_if_eq:VnTF \@currenvir {#1}
          { \__suts_free_begin:n {#1} }
          { \__suts_text_set:nn {#1} }
      }
    \cs_new_protected:cpn { end#1 }
      {
        \end{VerbatimOut}
        \__suts_text_set:nx {#1}
          { \exp_not:N \file_input:n { \g__suts_free_file_tl } \exp_not:N \unskip }
      }
  }

% \Reference{key}{internal | external}{document}{version}
%   numbered [R1], [R2], ... ; cite with \DocRef{key}
\prop_new:N \g__suts_refnum_prop
\str_new:N \l__suts_scope_str
\tl_new:N \l__suts_scope_tl
\NewDocumentCommand \Reference { m m +m m }
  {
    \int_gincr:N \g__suts_references_int
    \prop_gput:Nnx \g__suts_refnum_prop {#1} { \int_use:N \g__suts_references_int }
    \str_set:Nx \l__suts_scope_str { \str_lowercase:n {#2} }
    \str_case:VnF \l__suts_scope_str
      {
        {internal} { \tl_set:Nn \l__suts_scope_tl { internal } }
        {int}      { \tl_set:Nn \l__suts_scope_tl { internal } }
        {i}        { \tl_set:Nn \l__suts_scope_tl { internal } }
        {external} { \tl_set:Nn \l__suts_scope_tl { external } }
        {ext}      { \tl_set:Nn \l__suts_scope_tl { external } }
        {e}        { \tl_set:Nn \l__suts_scope_tl { external } }
      }
      {
        \msg_warning:nnnn { suts } { bad-scope } {#1} {#2}
        \tl_set:Nn \l__suts_scope_tl { \textcolor{warn}{#2} }
      }
    \tl_gput_right:Nx \g__suts_references_tl
      {
        { [R\int_use:N \g__suts_references_int] }
        \exp_not:n { & #3 & } \exp_not:V \l__suts_scope_tl \exp_not:n { & #4 \\ }
      }
  }
\msg_new:nnn { suts } { bad-scope }
  { \Reference{#1}:~'#2'~is~neither~'internal'~nor~'external'. }
\NewDocumentCommand \DocRef { m }
  {
    \prop_get:NnNTF \g__suts_refnum_prop {#1} \l_tmpa_tl
      { [R\tl_use:N \l_tmpa_tl] }
      { \textcolor{warn}{[?#1]} \msg_warning:nnn { suts } { unknown-ref } {#1} }
  }
\msg_new:nnn { suts } { unknown-ref } { \DocRef{#1}:~no~\Reference{#1}{..}{..}~defined. }

% \Term{abbreviation}{definition}
\NewDocumentCommand \Term { m +m }
  { \__suts_add:nn { terms } { #1 & #2 \\ } }

% =============================================================================
%  Input commands: unit under test  (content/unit.tex)
% =============================================================================
% \Interface{name}{direction}{type / range}{description}
\seq_new:N \g__suts_ifnames_seq
\NewDocumentCommand \Interface { m m m +m }
  {
    \__suts_add:nn { interfaces } { \texttt{#1} & #2 & #3 & #4 \\ }
    \seq_gput_right:Nn \g__suts_ifnames_seq {#1}
  }
% \Dependency[component]{name}{replaced by}{behaviour in test}
%   [component] groups functions into one box in the diagrams (default: the name)
\seq_new:N \g__suts_depcomp_seq            % components, in order
\prop_new:N \g__suts_depfun_prop           % component -> functions
\prop_new:N \g__suts_depdbl_prop           % component -> replaced by
\NewDocumentCommand \Dependency { o m m +m }
  {
    \__suts_add:nn { dependencies } { \texttt{#2} & #3 & #4 \\ }
    \tl_set:Nx \l_tmpb_tl { \IfNoValueTF {#1} { \exp_not:n {#2} } { \exp_not:n {#1} } }
    \seq_if_in:NVF \g__suts_depcomp_seq \l_tmpb_tl
      {
        \seq_gput_right:NV \g__suts_depcomp_seq \l_tmpb_tl
        \prop_gput:NVn \g__suts_depdbl_prop \l_tmpb_tl {#3}
      }
    \prop_get:NVNTF \g__suts_depfun_prop \l_tmpb_tl \l_tmpa_tl
      { \tl_put_right:Nn \l_tmpa_tl { ,~#2 } }
      { \tl_set:Nn \l_tmpa_tl {#2} }
    \prop_gput:NVV \g__suts_depfun_prop \l_tmpb_tl \l_tmpa_tl
  }
% \Caller{component}{interfaces it uses}   -- left side of the context diagram
\seq_new:N \g__suts_callers_seq
\NewDocumentCommand \Caller { m m }
  { \seq_gput_right:Nn \g__suts_callers_seq { {#1} {#2} } }

% ---------------------------------------------------------------- diagrams ---
% Generic block diagram: left boxes -> centre box -> right boxes.
% Items of the side seqs: {name}{stereotype}{arrow label}{style}
\seq_new:N \l__suts_left_seq
\seq_new:N \l__suts_right_seq
\dim_new:N \l__suts_step_dim
\dim_set:Nn \l__suts_step_dim { 1.7cm }
\cs_new:Npn \__suts_y:nnn #1#2#3   % y of item #2 of #3, spacing #1
  { \fp_to_dim:n { #1 * (#3 + 1 - 2 * #2) / 2 } }
\cs_new:Npn \__suts_y:nn #1#2 { \__suts_y:nnn { \l__suts_step_dim } {#1} {#2} }
\cs_new_protected:Npn \__suts_side:nnnnnnn #1#2#3#4#5#6#7
  % #1 L/R  #2 index  #3 count  #4 name  #5 stereotype  #6 label  #7 style
  {
    \node [ suts/#7 ] (#1#2) at ( \str_if_eq:nnTF {#1} {L} { -7.4cm } { 7.4cm } , \__suts_y:nn {#2} {#3} )
      {
        \tl_if_empty:nF {#5}
          { {\scriptsize\guillemotleft \text_lowercase:n {#5} \guillemotright} \\ }
        \textbf{#4}
      } ;
    \clist_set:Nn \l_tmpa_clist {#6}   % one interface per line
    \str_if_eq:nnTF {#1} {L}
      { \draw [ suts/use ] (#1#2.east) -- (#1#2.east -| U.west) node [ suts/lbl ] { \clist_use:Nn \l_tmpa_clist { \\ } } ; }
      { \draw [ suts/use ] (#1#2.west -| U.east) -- (#1#2.west) node [ suts/lbl ] { \clist_use:Nn \l_tmpa_clist { \\ } } ; }
  }
\cs_new_protected:Npn \__suts_block_diagram:nnn #1#2#3
  % #1 centre stereotype  #2 centre name  #3 centre style
  {
    \int_set:Nn \l_tmpa_int
      { \int_max:nn { 1 } { \int_max:nn { \seq_count:N \l__suts_left_seq } { \seq_count:N \l__suts_right_seq } } }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \node [ suts/#3 , minimum~height = \dim_eval:n { \l__suts_step_dim * \l_tmpa_int - 0.3cm } ] (U) at (0,0)
        { {\scriptsize\guillemotleft#1\guillemotright} \\ \textbf{#2} } ;
      \seq_map_indexed_inline:Nn \l__suts_left_seq
        { \__suts_side:nnnnnnn {L} {##1} { \seq_count:N \l__suts_left_seq } ##2 }
      \seq_map_indexed_inline:Nn \l__suts_right_seq
        { \__suts_side:nnnnnnn {R} {##1} { \seq_count:N \l__suts_right_seq } ##2 }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__suts_right_from_deps:n #1   % #1: true = show test doubles
  {
    \seq_clear:N \l__suts_right_seq
    \seq_map_inline:Nn \g__suts_depcomp_seq
      {
        \prop_get:NnN \g__suts_depfun_prop {##1} \l_tmpa_tl
        \prop_get:NnN \g__suts_depdbl_prop {##1} \l_tmpb_tl
        \bool_if:nTF {#1}
          { \seq_put_right:Nx \l__suts_right_seq { {##1} { \exp_not:V \l_tmpb_tl } { \exp_not:V \l_tmpa_tl } {double} } }
          { \seq_put_right:Nx \l__suts_right_seq { {##1} {component} { \exp_not:V \l_tmpa_tl } {comp} } }
      }
  }
\cs_new_protected:Npn \__suts_add_caller:nn #1#2
  { \seq_put_right:Nn \l__suts_left_seq { {#1} {component} {#2} {comp} } }
% context: callers -> unit -> dependencies
\cs_new_protected:Npn \__suts_context_diagram:
  {
    \seq_clear:N \l__suts_left_seq
    \seq_map_inline:Nn \g__suts_callers_seq { \__suts_add_caller:nn ##1 }
    \__suts_right_from_deps:n { \c_false_bool }
    \__suts_block_diagram:nnn { unit } { \__suts_meta:n { UnitName } } { unit }
  }
% harness: test driver -> UUT -> test doubles
\cs_new_protected:Npn \__suts_harness_diagram:
  {
    \seq_clear:N \l__suts_left_seq
    \seq_put_right:Nx \l__suts_left_seq
      { {Test~driver} {test} { \seq_use:Nn \g__suts_ifnames_seq { ,~ } } {driver} }
    \__suts_right_from_deps:n { \c_true_bool }
    \__suts_block_diagram:nnn { UUT } { \__suts_meta:n { UnitName } } { unit }
  }

% use cases: \UseCase{use case}{actor, actor}
\seq_new:N \g__suts_usecases_seq
\seq_new:N \g__suts_actors_seq
\NewDocumentCommand \UseCase { m m }
  {
    \seq_gput_right:Nn \g__suts_usecases_seq { {#1} {#2} }
    \clist_set:Nn \l_tmpa_clist {#2}
    \clist_map_inline:Nn \l_tmpa_clist
      { \seq_if_in:NnF \g__suts_actors_seq {##1} { \seq_gput_right:Nn \g__suts_actors_seq {##1} } }
  }
\cs_new_protected:Npn \__suts_usecase_diagram:
  {
    \int_set:Nn \l_tmpa_int { \seq_count:N \g__suts_usecases_seq }
    \int_set:Nn \l_tmpb_int { \seq_count:N \g__suts_actors_seq }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \seq_map_indexed_inline:Nn \g__suts_actors_seq
        {
          \pic (A##1) at ( -4.5cm , \__suts_y:nnn { 2.4cm } {##1} { \l_tmpb_int } ) {suts@actor={##2}} ;
        }
      \seq_map_indexed_inline:Nn \g__suts_usecases_seq
        { \__suts_usecase:nnnn {##1} { \l_tmpa_int } ##2 }
      \node [ suts/boundary , fit = { (UC1) (UClast) } ] (B) {} ;
      \node [ anchor = south , font = \small , align = center ] at (B.north)
        { {\scriptsize\guillemotleft system\guillemotright} \\ \textbf{ \__suts_meta:n { ProjectName } } } ;
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__suts_usecase:nnnn #1#2#3#4   % index count name actors
  {
    \node [ suts/usecase , alias = UClast ] (UC#1) at ( 3cm , \__suts_y:nnn { 1.5cm } {#1} {#2} ) {#3} ;
    \clist_set:Nn \l_tmpa_clist {#4}
    \clist_map_inline:Nn \l_tmpa_clist
      {
        \seq_map_indexed_inline:Nn \g__suts_actors_seq
          { \str_if_eq:nnT {##1} {####2} { \draw [ suts/assoc ] (A####1-body) -- (UC#1) ; } }
      }
  }

% =============================================================================
%  Input commands: test approach  (content/approach.tex)
% =============================================================================
% \VerificationMethod{method}{yes|no}{remark}
\NewDocumentCommand \VerificationMethod { m m +m }
  {
    \__suts_add:nn { methods }
      { #1 & \__suts_check:n {#2} & #3 \\ }
  }
\cs_new:Npn \__suts_check:n #1
  {
    \str_if_eq:eeTF { \str_lowercase:n {#1} } { yes } { $\boxtimes$ }
      { \str_if_eq:eeTF { \str_lowercase:n {#1} } { no } { $\square$ } {#1} }
  }
\NewDocumentCommand \DerivationTechnique { +m } { \__suts_add:nn { derivation } { \item #1 } }
% \Coverage{metric}{target}{justification if not met}   -- target 100 -> 100 %
\NewDocumentCommand \Coverage { m m +m }
  { \__suts_add:nn { coverage } { #1 & \__suts_pct:n {#2} & #3 \\ } }
\NewDocumentCommand \EntryCriterion { +m } { \__suts_add:nn { entry } { \item #1 } }
\NewDocumentCommand \ExitCriterion  { +m } { \__suts_add:nn { exit }  { \item #1 } }

% =============================================================================
%  Input commands: test environment  (content/environment.tex)
% =============================================================================
% \Tool{item}{description}{version}
\NewDocumentCommand \Tool { m +m m }
  { \__suts_add:nn { environment } { #1 & #2 & #3 \\ } }

% =============================================================================
%  Input commands: requirements  (content/requirements.tex)
% =============================================================================
% \StakeholderRequirement{ID}{functional | non-functional}{text}{source}
% \InternalRequirement{ID}{functional | non-functional}{text}{derived from: ID, ID}
% \NotUnitTested{ID}{rationale / where it is verified instead}
\seq_new:N \g__suts_req_seq
\prop_new:N \g__suts_reqdesc_prop
\prop_new:N \g__suts_reqlevel_prop       % S (stakeholder) / I (internal)
\prop_new:N \g__suts_reqkind_prop        % F / NF
\prop_new:N \g__suts_reqsrc_prop         % source (S) or parent IDs (I)
\prop_new:N \g__suts_reqchild_prop       % parent -> internal children
\prop_new:N \g__suts_reqtc_prop          % requirement -> linked test cases
\prop_new:N \g__suts_reqnot_prop         % requirement -> rationale
\str_new:N \l__suts_kind_str
\tl_new:N \l__suts_kindv_tl
\cs_generate_variant:Nn \str_case:nnF { V }
\cs_new_protected:Npn \__suts_req_add:nnnnn #1#2#3#4#5   % level ID kind text src
  {
    \prop_if_in:NnT \g__suts_reqdesc_prop {#2}
      { \msg_warning:nnn { suts } { duplicate-req } {#2} }
    \seq_gput_right:Nn \g__suts_req_seq {#2}
    \prop_gput:Nnn \g__suts_reqdesc_prop {#2} {#4}
    \prop_gput:Nnn \g__suts_reqlevel_prop {#2} {#1}
    \prop_gput:Nnn \g__suts_reqsrc_prop {#2} {#5}
    \str_set:Nx \l__suts_kind_str { \str_lowercase:n {#3} }
    \str_case:VnF \l__suts_kind_str
      {
        {functional}     { \tl_set:Nn \l__suts_kindv_tl {F} }
        {f}              { \tl_set:Nn \l__suts_kindv_tl {F} }
        {non-functional} { \tl_set:Nn \l__suts_kindv_tl {NF} }
        {nonfunctional}  { \tl_set:Nn \l__suts_kindv_tl {NF} }
        {nf}             { \tl_set:Nn \l__suts_kindv_tl {NF} }
      }
      {   % unknown kind: warn, list it as functional
        \msg_warning:nnnn { suts } { bad-kind } {#2} {#3}
        \tl_set:Nn \l__suts_kindv_tl {F}
      }
    \prop_gput:NnV \g__suts_reqkind_prop {#2} \l__suts_kindv_tl
    \str_if_eq:nnT {#1} {I}
      {
        \clist_set:Nn \l_tmpa_clist {#5}
        \clist_map_inline:Nn \l_tmpa_clist
          {
            \prop_get:NnNTF \g__suts_reqchild_prop {##1} \l_tmpa_tl
              { \tl_put_right:Nn \l_tmpa_tl { , #2 } }
              { \tl_set:Nn \l_tmpa_tl {#2} }
            \prop_gput:NnV \g__suts_reqchild_prop {##1} \l_tmpa_tl
          }
      }
  }
\msg_new:nnn { suts } { duplicate-req } { Requirement~#1~declared~twice. }
\msg_new:nnn { suts } { bad-kind }
  { Requirement~#1:~kind~'#2'~is~neither~'functional'~nor~'non-functional';~listed~as~functional. }
\NewDocumentCommand \StakeholderRequirement { m m +m +m }
  { \__suts_req_add:nnnnn {S} {#1} {#2} {#3} {#4} }
\NewDocumentCommand \InternalRequirement { m m +m m }
  { \__suts_req_add:nnnnn {I} {#1} {#2} {#3} {#4} }
\NewDocumentCommand \NotUnitTested { m +m }
  { \prop_gput:Nnn \g__suts_reqnot_prop {#1} {#2} }

% =============================================================================
%  Input commands: test cases  (content/testcases.tex)
% =============================================================================
% \TestGroup{title}                         -- subsection heading
% \begin{TestCase}{ID}{title} fields... \end{TestCase}
%   fields (any order, all optional): \Objective \Verifies{REQ, REQ} \Method
%   \Priority \Preconditions \InputData \InputValue{name}{value}{class}
%   \Step{action}{expected result} \Postconditions \Implementation
%
% testcases.tex is read twice: in the preamble (scan: counts test cases and
% links requirements, so tables work regardless of chapter order) and where
% \SpecTestCases is placed (render).
\bool_new:N \g__suts_scan_bool
\int_new:N \g__suts_tc_int
\seq_new:N \g__suts_tc_seq
\clist_const:Nn \c__suts_tcfields_clist
  { Objective, Verifies, Method, Priority, Preconditions, InputData,
    Postconditions, Implementation }
\clist_map_inline:Nn \c__suts_tcfields_clist { \tl_new:c { g__suts_tc_#1_tl } }
\tl_new:N \g__suts_tc_steps_tl
\tl_new:N \g__suts_tc_inputs_tl

\NewDocumentCommand \TestGroup { m }
  { \bool_if:NF \g__suts_scan_bool { \subsection{#1} } }

\cs_new_protected:Npn \__suts_tc_field:nn #1#2
  { \tl_gset:cn { g__suts_tc_#1_tl } {#2} }

\NewDocumentEnvironment { TestCase } { m m +b }
  {
    \clist_map_inline:Nn \c__suts_tcfields_clist { \tl_gclear:c { g__suts_tc_##1_tl } }
    \tl_gclear:N \g__suts_tc_steps_tl
    \tl_gclear:N \g__suts_tc_inputs_tl
    \hbox_set:Nn \l_tmpa_box   % collect fields; stray text is discarded
      {
        \clist_map_inline:Nn \c__suts_tcfields_clist
          { \cs_set_protected:cpn {##1} ####1 { \__suts_tc_field:nn {##1} {####1} } }
        \cs_set_protected:Npn \Step ##1##2
          { \tl_gput_right:Nn \g__suts_tc_steps_tl { \stepcounter{tcstepno} \thetcstepno & ##1 & ##2 \\ } }
        \cs_set_protected:Npn \InputValue ##1##2##3
          { \tl_gput_right:Nn \g__suts_tc_inputs_tl { \texttt{##1} & ##2 & ##3 \\ } }
        #3
      }
    \bool_if:NTF \g__suts_scan_bool
      { \__suts_tc_scan:n {#1} }
      { \__suts_tc_render:nn {#1} {#2} }
  }
  { }

\cs_new_protected:Npn \__suts_tc_scan:n #1
  {
    \seq_if_in:NnT \g__suts_tc_seq {#1}
      { \msg_warning:nnn { suts } { duplicate-tc } {#1} }
    \seq_gput_right:Nn \g__suts_tc_seq {#1}
    \int_gincr:N \g__suts_tc_int
    \clist_set:NV \l_tmpa_clist \g__suts_tc_Verifies_tl
    \clist_map_inline:Nn \l_tmpa_clist
      {
        \prop_get:NnNF \g__suts_reqtc_prop {##1} \l_tmpa_tl { \tl_clear:N \l_tmpa_tl }
        \tl_if_empty:NF \l_tmpa_tl { \tl_put_right:Nn \l_tmpa_tl { ,~ } }
        \tl_put_right:Nn \l_tmpa_tl { \hyperref[tc:#1]{#1} }
        \prop_gput:NnV \g__suts_reqtc_prop {##1} \l_tmpa_tl
      }
  }
\msg_new:nnn { suts } { duplicate-tc } { Test~case~ID~#1~used~twice. }

\newcounter{tcstepno}
\cs_new_protected:Npn \__suts_tc_item:nn #1#2   % \item[label] field, if set
  {
    \tl_if_empty:cF { g__suts_tc_#2_tl }
      { \item[#1] \tl_use:c { g__suts_tc_#2_tl } }
  }
\cs_new_protected:Npn \__suts_tc_render:nn #1#2
  {
    \addcontentsline{ltc}{testcase}{\protect\makebox[7em][l]{#1}#2}
    \begin{tcolorbox}[breakable, enhanced, colback=tcbg, colframe=accent,
        boxrule=0.6pt, arc=1.5pt, left=6pt, right=6pt,
        fonttitle=\bfseries, title={#1 \quad #2}]
    \phantomsection\label{tc:#1}
    \begin{description}[style=sameline, leftmargin=3.9cm, labelwidth=3.7cm,
                        font=\normalfont\bfseries\small, itemsep=1pt]
      \__suts_tc_item:nn { Objective }     { Objective }
      \__suts_tc_item:nn { Requirements }  { Verifies }
      \__suts_tc_item:nn { Method }        { Method }
      \__suts_tc_item:nn { Priority }      { Priority }
      \__suts_tc_item:nn { Preconditions } { Preconditions }
      \bool_lazy_and:nnF
        { \tl_if_empty_p:N \g__suts_tc_InputData_tl }
        { \tl_if_empty_p:N \g__suts_tc_inputs_tl }
        {
          \item[Input~data] \tl_use:N \g__suts_tc_InputData_tl
          \tl_if_empty:NF \g__suts_tc_inputs_tl
            {
              \tl_if_empty:NF \g__suts_tc_InputData_tl { \par }
              \begin{tabular}[t]{@{}lll@{}} \tl_use:N \g__suts_tc_inputs_tl \end{tabular}
            }
        }
      \tl_if_empty:NF \g__suts_tc_steps_tl
        {
          \item[Test~steps]
          \setcounter{tcstepno}{0}
          \small
          \begin{tabularx}{\linewidth}[t]{@{}r L{0.42\linewidth} Y@{}}
            \# & \textbf{Action~/~Stimulus} & \textbf{Expected~result} \\ \midrule
            \tl_use:N \g__suts_tc_steps_tl
            \bottomrule
          \end{tabularx}
        }
      \__suts_tc_item:nn { Postconditions } { Postconditions }
      \__suts_tc_item:nn { Implementation } { Implementation }
    \end{description}
    \end{tcolorbox}
  }

% =============================================================================
%  Input commands: results  (content/results.tex)
% =============================================================================
\clist_map_inline:nn { Executed, Passed, Failed }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { m }
      { \prop_gput:Nnn \g__suts_meta_prop {#1} {##1} }
  }
% \CoverageResult{metric}{achieved}     -- 98 -> 98 %
\NewDocumentCommand \CoverageResult { m m }
  { \__suts_add:nn { covresults } { #1~coverage & \__suts_pct:n {#2} \\ } }
% \Deviation{ID}{test case}{description / justification}{status}
\NewDocumentCommand \Deviation { m m +m m }
  { \__suts_add:nn { deviations } { #1 & #2 & #3 & #4 \\ } }

% =============================================================================
%  Free text  (any content file)
% =============================================================================
% \begin{FreeText} ... any LaTeX ... \end{FreeText}   (\end{FreeText} on its own line)
% The body is copied verbatim to \jobname.free-<file>-<n>.tex, so %, &, verbatim,
% listings, own tables all work. Placement: at the end of the chapter that the
% file belongs to; in testcases.tex (and in the main document body) exactly
% where it stands. Not inside a TestCase.
\tl_new:N \g__suts_chapter_tl
\tl_gset:Nn \g__suts_chapter_tl { inplace }
\int_new:N \g__suts_free_int
\tl_new:N \g__suts_free_file_tl
\cs_new_protected:Npn \__suts_free_begin:n #1   % #1: target name
  {
    \int_gincr:N \g__suts_free_int
    \tl_gset:Nx \g__suts_free_file_tl
      { \c_sys_jobname_str .free- #1 - \int_use:N \g__suts_free_int .tex }
    \VerbatimEnvironment
    \begin{VerbatimOut}{\g__suts_free_file_tl}
  }
\cs_generate_variant:Nn \__suts_free_begin:n { V }
\cs_new_protected:Npn \__suts_free_register:n #1
  {
    \seq_if_exist:cF { g__suts_free_#1_seq } { \seq_new:c { g__suts_free_#1_seq } }
    \seq_gput_right:cV { g__suts_free_#1_seq } \g__suts_free_file_tl
  }
\newenvironment{FreeText}
  { \__suts_free_begin:V \g__suts_chapter_tl }
  {
    \end{VerbatimOut}
    \__suts_free_done:
  }
% Named free-text blocks for fixed subsections (use them in design.tex or any
% content file except testcases.tex):
%   IntendedBehavior, InternalArchitecture, AlgorithmDescription
\clist_map_inline:nn { IntendedBehavior, InternalArchitecture, AlgorithmDescription }
  {
    \newenvironment{#1}
      { \__suts_free_begin:n {#1} }
      {
        \end{VerbatimOut}
        \bool_lazy_or:nnTF
          { \str_if_eq_p:Vn \g__suts_chapter_tl { testcases } }
          { \str_if_eq_p:Vn \g__suts_chapter_tl { inplace } }
          { \msg_warning:nnn { suts } { named-free-place } {#1} }
          { \__suts_free_register:n {#1} }
      }
  }
\msg_new:nnn { suts } { named-free-place }
  { #1~block~ignored:~put~it~into~a~content~file~such~as~design.tex~(not~testcases.tex). }
\cs_new_protected:Npn \__suts_free_done:
  {
    \bool_lazy_or:nnTF
      { \str_if_eq_p:Vn \g__suts_chapter_tl { testcases } }
      { \str_if_eq_p:Vn \g__suts_chapter_tl { inplace } }
      { \bool_if:NF \g__suts_scan_bool { \file_input:V \g__suts_free_file_tl } }
      { \__suts_free_register:V \g__suts_chapter_tl }
  }
\cs_generate_variant:Nn \file_input:n { V }
\cs_generate_variant:Nn \__suts_free_register:n { V }
% named block or placeholder
\cs_new_protected:Npn \__suts_free_or_ph:nn #1#2
  {
    \seq_if_exist:cTF { g__suts_free_#1_seq } { \__suts_free:n {#1} }
      { \ph{#2~--~\string\begin\string{#1\string}~in~content/design.tex} }
  }
% place the free text blocks of content file #1
\cs_new_protected:Npn \__suts_free:n #1
  {
    \seq_if_exist:cT { g__suts_free_#1_seq }
      { \par \seq_map_inline:cn { g__suts_free_#1_seq } { \file_input:n {##1} } }
  }

% =============================================================================
%  Loading content
% =============================================================================
% \LoadUnit{name}: loads the unit folder units/name (see \LoadContent).
%   Build-time override: if \SpecUnit is defined before the class, e.g.
%     latexmk -pdf -jobname=foo -usepretex='\def\SpecUnit{foo}' sw_unit_test_spec.tex
%   it replaces name. A unit folder without metadata.tex gives a warning.
% \LoadContent{dir}: reads dir/{metadata,introduction,requirements,unit,design,
%   approach,environment,results}.tex (missing files are skipped) and scans
%   dir/testcases.tex. Use in the preamble.
% Both set the search paths: unit first, then the shared folders at root level
%   figures: dir/figures/, figures/  (\includegraphics, \InputFigure)
%   code:    dir/code/,    code/     (\InputCode)
%   data:    dir/data/,    data/
%   data and code are also added to LaTeX's \input@path, so \input, \VerbatimInput,
%   \IfFileExists etc. find their files by name. \UnitDir expands to dir.
\tl_new:N \g__suts_dir_tl
\tl_new:N \l__suts_found_tl
\cs_new:Npn \UnitDir { \g__suts_dir_tl }
\cs_new_protected:Npn \__suts_input:n #1
  { \file_if_exist_input:nF { \g__suts_dir_tl / #1 .tex } { } }
\cs_new_protected:Npn \__suts_set_paths:
  {
    \use:x { \exp_not:N \graphicspath { { \g__suts_dir_tl / figures/ } { figures/ } } }
    \cs_if_exist:NF \input@path { \tl_gset:Nn \input@path { } }
    \tl_gput_left:Nx \input@path
      { { \g__suts_dir_tl / data/ } { \g__suts_dir_tl / code/ } { data/ } { code/ } }
  }
% \__suts_find:nnTF {kind}{file}: unit folder first, then shared folder;
% the path found is in \l__suts_found_tl.
% Names are turned into strings first: underscore makes _ active.
\tl_new:N \l__suts_name_tl
\prg_new_protected_conditional:Npnn \__suts_find:nn #1#2 { TF }
  {
    \tl_set:Nx \l__suts_name_tl { \tl_to_str:n {#2} }
    \file_if_exist:nTF { \g__suts_dir_tl / #1 / \l__suts_name_tl }
      {
        \tl_set:Nx \l__suts_found_tl { \g__suts_dir_tl / #1 / \l__suts_name_tl }
        \prg_return_true:
      }
      {
        \file_if_exist:nTF { #1 / \l__suts_name_tl }
          { \tl_set:Nx \l__suts_found_tl { #1 / \l__suts_name_tl } \prg_return_true: }
          { \prg_return_false: }
      }
  }
\msg_new:nnn { suts } { missing-file }
  { #1~`#2'~not~found~in~\g__suts_dir_tl / #1/~nor~in~#1/. }
\msg_new:nnn { suts } { missing-unit }
  { Unit~folder~`#1'~has~no~metadata.tex. }
\cs_new_protected:Npn \__suts_missing:nn #1#2
  {
    \msg_warning:nnnn { suts } { missing-file } {#1} {#2}
    \fbox { \textcolor{warn}{ missing~#1/#2 } }
  }
% \InputFigure[max width]{name}: figure code name.tex (a tikzpicture), typeset
% in the document (template colours, TikZ libraries, fonts apply); shrunk to
% max width (default \linewidth), never enlarged.
\NewDocumentCommand \InputFigure { O{\linewidth} m }
  {
    \__suts_find:nnTF { figures } { #2 .tex }
      { \begin{adjustbox}{max~width=#1} \input{\l__suts_found_tl} \end{adjustbox} }
      { \__suts_missing:nn { figures } { #2 .tex } }
  }
% \InputCode[fancyvrb options]{file}: a source file from code/, verbatim.
\NewDocumentCommand \InputCode { O{} m }
  {
    \__suts_find:nnTF { code } {#2}
      { \exp_args:NnV \__suts_verbatim_input:nn {#1} \l__suts_found_tl }
      { \__suts_missing:nn { code } {#2} }
  }
\cs_new_protected:Npn \__suts_verbatim_input:nn #1#2
  { \VerbatimInput [ fontsize = \small , #1 ] {#2} }
\NewDocumentCommand \LoadContent { m }
  {
    \tl_gset:Nx \g__suts_dir_tl { \tl_to_str:n {#1} }
    \typeout { suts:~content~folder~`\g__suts_dir_tl' }
    \__suts_set_paths:
    \clist_map_inline:nn
      { metadata, introduction, requirements, unit, design, approach, environment, results }
      { \tl_gset:Nn \g__suts_chapter_tl {##1} \__suts_input:n {##1} }
    \bool_gset_true:N \g__suts_scan_bool
    \tl_gset:Nn \g__suts_chapter_tl { testcases }
    \__suts_input:n { testcases }
    \bool_gset_false:N \g__suts_scan_bool
    \tl_gset:Nn \g__suts_chapter_tl { inplace }
  }
\NewDocumentCommand \LoadUnit { m }
  {
    \cs_if_exist:NTF \SpecUnit
      { \tl_set:Nx \l_tmpa_tl { units / \tl_to_str:N \SpecUnit } }
      { \tl_set:Nx \l_tmpa_tl { units / \tl_to_str:n {#1} } }
    \file_if_exist:nF { \l_tmpa_tl / metadata.tex }
      { \exp_args:NnnV \msg_warning:nnn { suts } { missing-unit } \l_tmpa_tl }
    \exp_args:NV \LoadContent \l_tmpa_tl
  }

% =============================================================================
%  Page layout
% =============================================================================
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\textbf{\__suts_meta:n{DocTitle}}\\\small \__suts_meta:n{UnitName}}
\fancyhead[R]{\small \__suts_meta:n{DocID}\ \textbar\ v\__suts_meta:n{DocVersion}\\\small \__suts_meta:n{DocStatus}}
\fancyfoot[L]{\small \__suts_meta:n{Company}}
\fancyfoot[R]{\small Page~\thepage\ of~\pageref*{LastPage}}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}

% List of test cases (works like \listoffigures)
\newcommand{\listoftestcases}{\section*{List~of~Test~Cases}\@starttoc{ltc}}
\newcommand{\l@testcase}{\@dottedtocline{1}{0em}{7.5em}}

% =============================================================================
%  Chapters -- placed in the main file, in any order, each optional
% =============================================================================
\NewDocumentCommand \SpecTitlePage {}
  {
    \hypersetup{pageanchor=false}   % title page: no duplicate page.1 anchor
    \begin{titlepage}
      \centering
      \vspace*{3cm}
      {\Large \__suts_meta:n{ProjectName}\par}
      \vspace{1cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{0.4cm}
      {\Huge\bfseries \__suts_meta:n{DocTitle}\par}
      \vspace{0.3cm}
      {\Large Unit:~\TheUnit\par}
      \vspace{0.4cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{2cm}
      \begin{tabular}{@{}ll@{}}
        \toprule
        Document~ID     & \__suts_meta:n{DocID} \\
        Version         & \__suts_meta:n{DocVersion} \\
        Status          & \__suts_meta:n{DocStatus} \\
        Date            & \__suts_meta:n{DocDate} \\
        Unit~baseline   & \__suts_meta:n{UnitBaseline} \\
        Integrity~level & \__suts_meta:n{IntegrityLevel} \\
        Author          & \__suts_meta:n{Author} \\
        \bottomrule
      \end{tabular}
      \vfill
      {\small \__suts_meta:n{Company}}
    \end{titlepage}
    \hypersetup{pageanchor=true}
  }

\NewDocumentCommand \SpecDocumentControl {}
  {
    \section*{Document~Control}
    \subsection*{Revision~History}
    \begin{xltabular}{\linewidth}{@{}l l L{3cm} Y@{}}
      \toprule
      \textbf{Version} & \textbf{Date} & \textbf{Author} & \textbf{Change} \\ \midrule
      \__suts_if_list_empty:nTF { revisions } { \__suts_none_row:n {4} } { \__suts_rows:n { revisions } }
      \bottomrule
    \end{xltabular}
    \subsection*{Review~and~Approval}
    \begin{tabularx}{\linewidth}{@{}l L{4cm} X l@{}}
      \toprule
      \textbf{Role} & \textbf{Name} & \textbf{Signature} & \textbf{Date} \\ \midrule
      Author   & \__suts_meta:n{Author}   & & \\
      Reviewer & \__suts_meta:n{Reviewer} & & \\
      Approver & \__suts_meta:n{Approver} & & \\
      \bottomrule
    \end{tabularx}
    \__suts_free:n { metadata }
  }

\NewDocumentCommand \SpecContents {}
  { \tableofcontents \listoftestcases \clearpage }

\NewDocumentCommand \SpecIntroduction {}
  {
    \section{Introduction}
    \subsection{Purpose}
    \__suts_text:nn { Purpose }
      {
        This~document~specifies~the~unit~tests~for~the~software~unit~\TheUnit.~
        It~defines~the~test~approach,~the~test~environment~and~the~individual~test~cases~
        used~to~verify~that~the~unit~fulfils~its~software~detailed~design~and~the~allocated~
        software~requirements.
      }
    \subsection{Scope}
    \__suts_text:nn { Scope } { \ph{Scope} }
    \seq_if_empty:NF \g__suts_usecases_seq
      {
        \subsection{Stakeholders~and~Use~Cases}
        \__suts_text:nn { UseCaseNote } { }
        \__suts_usecase_diagram:
      }
    \subsection{References}
    \begin{xltabular}{\linewidth}{@{}l Y l l@{}}
      \toprule
      \textbf{ID} & \textbf{Document} & \textbf{Type} & \textbf{Version} \\ \midrule
      \__suts_if_list_empty:nTF { references } { \__suts_none_row:n {4} } { \__suts_rows:n { references } }
      \bottomrule
    \end{xltabular}
    \subsection{Terms~and~Abbreviations}
    \begin{xltabular}{\linewidth}{@{}l Y@{}}
      \toprule
      \textbf{Term} & \textbf{Definition} \\ \midrule
      \__suts_if_list_empty:nTF { terms } { \__suts_none_row:n {2} } { \__suts_rows:n { terms } }
      \bottomrule
    \end{xltabular}
    \__suts_free:n { introduction }
  }

\NewDocumentCommand \SpecUnitUnderTest {}
  {
    \section{Unit~Under~Test}
    \subsection{Identification}
    \begin{tabularx}{\linewidth}{@{}L{4cm} Y@{}}
      \toprule
      Unit~name        & \TheUnit \\
      Baseline         & \__suts_meta:n{UnitBaseline} \\
      Source~files     & \__suts_meta:n{SourceFiles} \\
      Language         & \__suts_meta:n{Language} \\
      Integrity~level  & \__suts_meta:n{IntegrityLevel} \\
      Design~reference & \__suts_meta:n{DesignReference} \\
      \bottomrule
    \end{tabularx}
    \subsection{Functional~Description}
    \__suts_text:nn { FunctionalDescription } { \ph{FunctionalDescription} }
    \subsection{Intended~Behavior}
    \__suts_free_or_ph:nn { IntendedBehavior } { intended~behavior }
    \bool_lazy_and:nnF
      { \seq_if_empty_p:N \g__suts_callers_seq }
      { \seq_if_empty_p:N \g__suts_depcomp_seq }
      {
        \subsection{Context}
        Neighbours~of~\TheUnit{}:~callers~(left)~and~used~components~(right).
        \__suts_context_diagram:
      }
    \subsection{Interfaces}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} l L{2.6cm} Y@{}}
      \toprule
      \textbf{Interface} & \textbf{Dir.} & \textbf{Type~/~Range} & \textbf{Description} \\ \midrule
      \__suts_if_list_empty:nTF { interfaces } { \__suts_none_row:n {4} } { \__suts_rows:n { interfaces } }
      \bottomrule
    \end{xltabular}
    \subsection{Dependencies,~Stubs~and~Mocks}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{2.6cm} Y@{}}
      \toprule
      \textbf{Dependency} & \textbf{Replaced~by} & \textbf{Behaviour~in~test} \\ \midrule
      \__suts_if_list_empty:nTF { dependencies } { \__suts_none_row:n {3} } { \__suts_rows:n { dependencies } }
      \bottomrule
    \end{xltabular}
    \subsection{Internal~Architecture}
    \__suts_free_or_ph:nn { InternalArchitecture } { internal~architecture }
    \subsection{Algorithm~Description}
    \__suts_free_or_ph:nn { AlgorithmDescription } { algorithm~description }
    \__suts_free:n { unit }
    \__suts_free:n { design }
  }

\cs_new_protected:Npn \__suts_itemize:n #1
  {
    \__suts_if_list_empty:nTF {#1} { \ph{none} }
      { \begin{itemize}[nosep] \__suts_rows:n {#1} \end{itemize} }
  }
\NewDocumentCommand \SpecTestApproach {}
  {
    \section{Test~Approach}
    \subsection{Verification~Methods}
    Methods~applied~to~this~unit~(ISO~26262-6~Table~7~/~ASPICE~SWE.4):
    \begin{xltabular}{\linewidth}{@{}Y c L{6cm}@{}}
      \toprule
      \textbf{Method} & \textbf{Applied} & \textbf{Remark} \\ \midrule
      \__suts_if_list_empty:nTF { methods } { \__suts_none_row:n {3} } { \__suts_rows:n { methods } }
      \bottomrule
    \end{xltabular}
    \subsection{Test~Case~Derivation}
    Test~cases~are~derived~using:
    \__suts_itemize:n { derivation }
    \subsection{Structural~Coverage~Targets}
    \begin{tabularx}{\linewidth}{@{}l c Y@{}}
      \toprule
      \textbf{Metric} & \textbf{Target} & \textbf{Justification~if~not~met} \\ \midrule
      \__suts_if_list_empty:nTF { coverage } { \__suts_none_row:n {3} } { \__suts_rows:n { coverage } }
      \bottomrule
    \end{tabularx}
    \subsection{Entry~and~Exit~Criteria}
    \textbf{Entry:} \__suts_itemize:n { entry }
    \textbf{Exit:}  \__suts_itemize:n { exit }
    \subsection{Pass/Fail~Criteria}
    \__suts_text:nn { PassFailCriteria } { \ph{PassFailCriteria} }
    \__suts_free:n { approach }
  }

\NewDocumentCommand \SpecTestEnvironment {}
  {
    \section{Test~Environment}
    \seq_if_empty:NF \g__suts_depcomp_seq
      {
        Test~harness:~the~test~driver~calls~the~interfaces~of~the~UUT;~its~dependencies~are~replaced~by~test~doubles.
        \__suts_harness_diagram:
      }
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} Y l@{}}
      \toprule
      \textbf{Item} & \textbf{Description} & \textbf{Version} \\ \midrule
      \__suts_if_list_empty:nTF { environment } { \__suts_none_row:n {3} } { \__suts_rows:n { environment } }
      \bottomrule
    \end{xltabular}
    \par \__suts_text:nn { ToolQualification } { }
    \__suts_free:n { environment }
  }

\NewDocumentCommand \SpecTestCases {}
  {
    \section{Test~Cases}
    \tl_gset:Nn \g__suts_chapter_tl { testcases }
    \__suts_input:n { testcases }
    \tl_gset:Nn \g__suts_chapter_tl { inplace }
  }

% rows are built before the tables (no loops inside alignment cells)
\tl_new:N \l__suts_trace_tl
\tl_new:N \l__suts_uncov_tl
\tl_new:N \l__suts_rows_tl
\tl_new:N \l__suts_a_tl
\tl_new:N \l__suts_b_tl
\tl_new:N \l__suts_c_tl
\tl_new:N \l__suts_d_tl
\tl_new:N \l__suts_k_tl
\clist_new:N \l__suts_c_clist
% #2 := how requirement #1 is verified: its own test cases, and for a
% stakeholder requirement also "via" its verified internal children
\cs_new_protected:Npn \__suts_req_verified:nN #1#2
  {
    \prop_get:NnNF \g__suts_reqtc_prop {#1} #2 { \tl_clear:N #2 }
    \prop_get:NnNT \g__suts_reqchild_prop {#1} \l__suts_c_tl
      {
        \tl_clear:N \l__suts_d_tl
        \clist_set:NV \l__suts_c_clist \l__suts_c_tl
        \clist_map_inline:Nn \l__suts_c_clist
          {
            \prop_if_in:NnT \g__suts_reqtc_prop {##1}
              {
                \tl_if_empty:NF \l__suts_d_tl { \tl_put_right:Nn \l__suts_d_tl { ,~ } }
                \tl_put_right:Nn \l__suts_d_tl {##1}
              }
          }
        \tl_if_empty:NF \l__suts_d_tl
          {
            \tl_if_empty:NF #2 { \tl_put_right:Nn #2 { ;~ } }
            \tl_put_right:Nn #2 { via~ }
            \tl_put_right:NV #2 \l__suts_d_tl
          }
      }
  }
\cs_new:Npn \__suts_kind_label:n #1
  {
    \str_if_eq:eeTF { \prop_item:Nn \g__suts_reqlevel_prop {#1} } { S } { stakeholder } { internal } ,~
    \str_if_eq:eeTF { \prop_item:Nn \g__suts_reqkind_prop {#1} } { NF } { non-functional } { functional }
  }
\cs_new_protected:Npn \__suts_build_trace:
  {
    \tl_clear:N \l__suts_trace_tl
    \tl_clear:N \l__suts_uncov_tl
    \seq_map_inline:Nn \g__suts_req_seq
      {
        \prop_get:NnN \g__suts_reqdesc_prop {##1} \l__suts_a_tl
        \__suts_req_verified:nN {##1} \l__suts_b_tl
        \tl_if_empty:NT \l__suts_b_tl
          {
            \tl_set:Nn \l__suts_b_tl { \textit{none~--~see~\ref{suts:uncovered}} }
            \prop_get:NnNF \g__suts_reqnot_prop {##1} \l__suts_c_tl
              {
                \prop_get:NnNTF \g__suts_reqchild_prop {##1} \l__suts_d_tl
                  {   % stakeholder requirement: rationale lies with its derived requirements
                    \clist_set:NV \l__suts_c_clist \l__suts_d_tl
                    \tl_set:Nx \l__suts_c_tl
                      { via~derived~\clist_use:Nn \l__suts_c_clist { ,~ }~--~see~their~rationale }
                  }
                  { \tl_set:Nn \l__suts_c_tl { \textcolor{warn}{rationale~missing~(add~\string\NotUnitTested)} } }
              }
            \tl_put_right:Nx \l__suts_uncov_tl
              { \exp_not:n {##1} & \exp_not:V \l__suts_c_tl \exp_not:N \\ }
          }
        \tl_put_right:Nx \l__suts_trace_tl
          {
            \exp_not:n {##1} & { \exp_not:N \footnotesize \__suts_kind_label:n {##1} } &
            \exp_not:V \l__suts_a_tl & \exp_not:V \l__suts_b_tl \exp_not:N \\
          }
      }
    \prop_map_inline:Nn \g__suts_reqtc_prop   % verified but never declared
      {
        \prop_if_in:NnF \g__suts_reqdesc_prop {##1}   % prop keys compare as strings
          {
            \tl_put_right:Nn \l__suts_trace_tl
              { ##1 & & \textcolor{warn}{not~declared~in~requirements.tex} & ##2 \\ }
          }
      }
    \tl_if_empty:NT \l__suts_trace_tl { \tl_set:Nn \l__suts_trace_tl { \__suts_none_row:n {4} } }
    \tl_if_empty:NT \l__suts_uncov_tl { \tl_set:Nn \l__suts_uncov_tl { \__suts_none_row:n {2} } }
  }
% rows of one requirements table: level #1 (S/I), kind #2 (F/NF)
\cs_new_protected:Npn \__suts_req_rows:nn #1#2
  {
    \tl_clear:N \l__suts_rows_tl
    \seq_map_inline:Nn \g__suts_req_seq
      {
        \bool_lazy_and:nnT
          { \str_if_eq_p:ee { \prop_item:Nn \g__suts_reqlevel_prop {##1} } {#1} }
          { \str_if_eq_p:ee { \prop_item:Nn \g__suts_reqkind_prop {##1} } {#2} }
          {
            \prop_get:NnN \g__suts_reqdesc_prop {##1} \l__suts_a_tl
            \prop_get:NnN \g__suts_reqsrc_prop {##1} \l__suts_k_tl
            \str_if_eq:nnT {#1} {I}   % parents: unknown IDs in red
              {
                \clist_set:NV \l__suts_c_clist \l__suts_k_tl
                \tl_clear:N \l__suts_k_tl
                \clist_map_inline:Nn \l__suts_c_clist
                  {
                    \tl_if_empty:NF \l__suts_k_tl { \tl_put_right:Nn \l__suts_k_tl { ,~ } }
                    \prop_if_in:NnTF \g__suts_reqdesc_prop {####1}
                      { \tl_put_right:Nn \l__suts_k_tl {####1} }
                      { \tl_put_right:Nn \l__suts_k_tl { \textcolor{warn}{####1~(unknown)} } }
                  }
                \tl_if_empty:NT \l__suts_k_tl { \tl_set:Nn \l__suts_k_tl { -- } }
              }
            \__suts_req_verified:nN {##1} \l__suts_b_tl
            \tl_if_empty:NT \l__suts_b_tl
              { \tl_set:Nn \l__suts_b_tl { \textit{not~unit~tested~(\ref{suts:uncovered})} } }
            \tl_put_right:Nx \l__suts_rows_tl
              {
                \exp_not:n {##1} & \exp_not:V \l__suts_a_tl & \exp_not:V \l__suts_k_tl &
                \exp_not:V \l__suts_b_tl \exp_not:N \\
              }
          }
      }
    \tl_if_empty:NT \l__suts_rows_tl { \tl_set:Nn \l__suts_rows_tl { \__suts_none_row:n {4} } }
  }
\cs_new_protected:Npn \__suts_req_table:nnn #1#2#3   % level kind third-column header
  {
    \__suts_req_rows:nn {#1} {#2}
    \begin{xltabular}{\linewidth}{@{}L{2.1cm} Y L{2.6cm} L{3.2cm}@{}}
      \toprule
      \textbf{ID} & \textbf{Requirement} & \textbf{#3} & \textbf{Verified~by} \\ \midrule
      \endhead
      \tl_use:N \l__suts_rows_tl
      \bottomrule
    \end{xltabular}
  }
\NewDocumentCommand \SpecRequirements {}
  {
    \section{Requirements}
    Stakeholder~requirements~state~what~users~and~other~stakeholders~need~from~\TheUnit;~
    internal~requirements~are~derived~from~them~(or~from~the~design)~and~are~what~the~unit~
    tests~verify.~A~stakeholder~requirement~counts~as~verified~via~its~verified~internal~requirements.
    \Needspace{8\baselineskip}
    \subsection{Stakeholder~Requirements}
    \subsubsection{Functional}
    \__suts_req_table:nnn {S} {F} {Source}
    \Needspace{6\baselineskip}
    \subsubsection{Non-Functional}
    \__suts_req_table:nnn {S} {NF} {Source}
    \Needspace{8\baselineskip}
    \subsection{Internal~Requirements}
    \subsubsection{Functional}
    \__suts_req_table:nnn {I} {F} {Derived~from}
    \Needspace{6\baselineskip}
    \subsubsection{Non-Functional}
    \__suts_req_table:nnn {I} {NF} {Derived~from}
    \__suts_free:n { requirements }
  }
\NewDocumentCommand \SpecTraceability {}
  {
    \__suts_build_trace:
    \section{Traceability}
    \Needspace{8\baselineskip}
    \subsection{Requirements~to~Test~Cases}
    \begin{xltabular}{\linewidth}{@{}L{2.5cm} L{2.2cm} Y L{3.6cm}@{}}
      \toprule
      \textbf{Requirement} & \textbf{Type} & \textbf{Description} & \textbf{Test~cases} \\ \midrule
      \endhead
      \tl_use:N \l__suts_trace_tl
      \bottomrule
    \end{xltabular}
    \Needspace{6\baselineskip}
    \subsection{Uncovered~Requirements}\label{suts:uncovered}
    Requirements~that~no~test~case~verifies~(directly~or,~for~stakeholder~requirements,~via~internal~ones):
    \begin{xltabular}{\linewidth}{@{}L{2.5cm} Y@{}}
      \toprule
      \textbf{Requirement} & \textbf{Rationale~/~verified~instead~by} \\ \midrule
      \tl_use:N \l__suts_uncov_tl
      \bottomrule
    \end{xltabular}
  }

\NewDocumentCommand \SpecResults {}
  {
    \section{Test~Results~Summary}
    \__suts_text:nn { ResultsNote } { } \par
    \begin{tabularx}{\linewidth}{@{}Y r@{}}
      \toprule
      Test~cases~specified       & \int_use:N \g__suts_tc_int \\
      Executed~/~Passed~/~Failed & \__suts_meta:n{Executed}~/~\__suts_meta:n{Passed}~/~\__suts_meta:n{Failed} \\
      \__suts_rows:n { covresults }
      Deviations                 & \__suts_count:n { deviations } \\
      \bottomrule
    \end{tabularx}
    \subsection{Deviations}
    \begin{xltabular}{\linewidth}{@{}l L{3cm} Y l@{}}
      \toprule
      \textbf{ID} & \textbf{Test~case} & \textbf{Description~/~Justification} & \textbf{Status} \\ \midrule
      \__suts_if_list_empty:nTF { deviations } { \__suts_none_row:n {4} } { \__suts_rows:n { deviations } }
      \bottomrule
    \end{xltabular}
    \__suts_free:n { results }
  }
\ExplSyntaxOff

% ------------------------------------------------------------ diagram styles ---
\colorlet{sutsunit}{accent!12}
\colorlet{sutsdouble}{orange!15}
\tikzset{
  suts/box/.style   = {draw=accent, rectangle, align=center, font=\small,
                       text width=2.9cm, minimum height=1.1cm, inner sep=3pt,
                       execute at begin node={\lefthyphenmin=62 }}, % no word hyphenation, breaks after _ stay
  suts/comp/.style  = {suts/box, fill=white},
  suts/driver/.style= {suts/box, fill=sutsdouble},
  suts/double/.style= {suts/box, fill=sutsdouble, dashed},
  suts/unit/.style  = {suts/box, fill=sutsunit, very thick, text width=3.4cm},
  suts/use/.style   = {-{Stealth[open]}, dashed, accent},
  suts/lbl/.style   = {midway, above, font=\scriptsize\ttfamily, align=center},
  suts/usecase/.style = {draw=accent, ellipse, fill=sutsunit, align=center,
                       font=\small, text width=3.6cm, inner sep=1pt, minimum height=1.1cm},
  suts/boundary/.style= {draw=accent, rectangle, inner sep=8pt},
  suts/assoc/.style = {accent},
  suts@actor/.pic   = {
    \draw[accent, thick] (0,0.45) circle (0.15)
      (0,0.3) -- (0,-0.1) (-0.25,0.15) -- (0.25,0.15)
      (0,-0.1) -- (-0.2,-0.45) (0,-0.1) -- (0.2,-0.45);
    \coordinate (-body) at (0.3,0.1);
    \node[below, font=\small, align=center, text width=2.6cm] at (0,-0.5) {#1};
  },
}
\endinput
