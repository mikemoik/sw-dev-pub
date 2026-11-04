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
\RequirePackage[strings,nohyphen]{underscore} % plain _ in text: unit_name, Unit_Init()
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
\RequirePackage{tikz}
\usetikzlibrary{arrows.meta,positioning,fit,calc,shapes.geometric}
\RequirePackage[export]{adjustbox}      % diagrams shrink to the text width if needed
\RequirePackage{fancyvrb}               % FreeText: body copied verbatim to a file
\RequirePackage[hidelinks]{hyperref}

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
\clist_map_inline:nn
  { Purpose, Scope, UseCaseNote, FunctionalDescription, PassFailCriteria,
    ToolQualification, ResultsNote }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { +m }
      { \prop_gput:Nnn \g__suts_text_prop {#1} {##1} }
  }

% \Reference{key}{document}{version}  -- numbered [R1], [R2], ... ; cite with \DocRef{key}
\prop_new:N \g__suts_refnum_prop
\NewDocumentCommand \Reference { m +m m }
  {
    \int_gincr:N \g__suts_references_int
    \prop_gput:Nnx \g__suts_refnum_prop {#1} { \int_use:N \g__suts_references_int }
    \tl_gput_right:Nx \g__suts_references_tl
      { { [R\int_use:N \g__suts_references_int] } \exp_not:n { & #2 & #3 \\ } }
  }
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
    \str_if_eq:eeTF { \str_casefold:n {#1} } { yes } { $\boxtimes$ }
      { \str_if_eq:eeTF { \str_casefold:n {#1} } { no } { $\square$ } {#1} }
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
% \Requirement{ID}{short description}
% \NotUnitTested{ID}{rationale / where it is verified instead}
\seq_new:N \g__suts_req_seq
\prop_new:N \g__suts_reqdesc_prop
\prop_new:N \g__suts_reqtc_prop          % requirement -> linked test cases
\prop_new:N \g__suts_reqnot_prop         % requirement -> rationale
\NewDocumentCommand \Requirement { m +m }
  {
    \seq_gput_right:Nn \g__suts_req_seq {#1}
    \prop_gput:Nnn \g__suts_reqdesc_prop {#1} {#2}
  }
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
\newenvironment{FreeText}
  {
    \int_gincr:N \g__suts_free_int
    \tl_gset:Nx \g__suts_free_file_tl
      { \c_sys_jobname_str .free- \g__suts_chapter_tl - \int_use:N \g__suts_free_int .tex }
    \VerbatimEnvironment
    \begin{VerbatimOut}{\g__suts_free_file_tl}
  }
  {
    \end{VerbatimOut}
    \__suts_free_done:
  }
\cs_new_protected:Npn \__suts_free_done:
  {
    \bool_lazy_or:nnTF
      { \str_if_eq_p:Vn \g__suts_chapter_tl { testcases } }
      { \str_if_eq_p:Vn \g__suts_chapter_tl { inplace } }
      { \bool_if:NF \g__suts_scan_bool { \file_input:V \g__suts_free_file_tl } }
      {
        \seq_if_exist:cF { g__suts_free_ \g__suts_chapter_tl _seq }
          { \seq_new:c { g__suts_free_ \g__suts_chapter_tl _seq } }
        \seq_gput_right:cV { g__suts_free_ \g__suts_chapter_tl _seq } \g__suts_free_file_tl
      }
  }
\cs_generate_variant:Nn \file_input:n { V }
% place the free text blocks of content file #1
\cs_new_protected:Npn \__suts_free:n #1
  {
    \seq_if_exist:cT { g__suts_free_#1_seq }
      { \par \seq_map_inline:cn { g__suts_free_#1_seq } { \file_input:n {##1} } }
  }

% =============================================================================
%  Loading content
% =============================================================================
% \LoadContent{dir}: reads dir/{metadata,introduction,unit,approach,
% environment,requirements,results}.tex (missing files are skipped) and scans
% dir/testcases.tex. Use in the preamble.
\tl_new:N \g__suts_dir_tl
\cs_new_protected:Npn \__suts_input:n #1
  { \file_if_exist_input:nF { \g__suts_dir_tl / #1 .tex } { } }
\NewDocumentCommand \LoadContent { m }
  {
    \tl_gset:Nn \g__suts_dir_tl {#1}
    \clist_map_inline:nn
      { metadata, introduction, unit, approach, environment, requirements, results }
      { \tl_gset:Nn \g__suts_chapter_tl {##1} \__suts_input:n {##1} }
    \bool_gset_true:N \g__suts_scan_bool
    \tl_gset:Nn \g__suts_chapter_tl { testcases }
    \__suts_input:n { testcases }
    \bool_gset_false:N \g__suts_scan_bool
    \tl_gset:Nn \g__suts_chapter_tl { inplace }
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
    \begin{xltabular}{\linewidth}{@{}l Y l@{}}
      \toprule
      \textbf{ID} & \textbf{Document} & \textbf{Version} \\ \midrule
      \__suts_if_list_empty:nTF { references } { \__suts_none_row:n {3} } { \__suts_rows:n { references } }
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
    \__suts_free:n { unit }
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
\tl_new:N \l__suts_a_tl
\tl_new:N \l__suts_b_tl
\cs_new_protected:Npn \__suts_build_trace:
  {
    \tl_clear:N \l__suts_trace_tl
    \tl_clear:N \l__suts_uncov_tl
    \seq_map_inline:Nn \g__suts_req_seq
      {
        \prop_get:NnN \g__suts_reqdesc_prop {##1} \l__suts_a_tl
        \prop_get:NnNTF \g__suts_reqtc_prop {##1} \l__suts_b_tl
          { }
          {
            \tl_set:Nn \l__suts_b_tl { \textit{none~--~see~\ref{suts:uncovered}} }
            \prop_get:NnNF \g__suts_reqnot_prop {##1} \l__suts_a_tl
              { \tl_set:Nn \l__suts_a_tl { \textcolor{warn}{rationale~missing~(add~\string\NotUnitTested)} } }
            \tl_put_right:Nx \l__suts_uncov_tl
              { \exp_not:n {##1} & \exp_not:V \l__suts_a_tl \exp_not:N \\ }
            \prop_get:NnN \g__suts_reqdesc_prop {##1} \l__suts_a_tl
          }
        \tl_put_right:Nx \l__suts_trace_tl
          { \exp_not:n {##1} & \exp_not:V \l__suts_a_tl & \exp_not:V \l__suts_b_tl \exp_not:N \\ }
      }
    \prop_map_inline:Nn \g__suts_reqtc_prop   % verified but never declared
      {
        \prop_if_in:NnF \g__suts_reqdesc_prop {##1}   % prop keys compare as strings
          {
            \tl_put_right:Nn \l__suts_trace_tl
              { ##1 & \textcolor{warn}{not~declared~in~requirements.tex} & ##2 \\ }
          }
      }
    \tl_if_empty:NT \l__suts_trace_tl { \tl_set:Nn \l__suts_trace_tl { \__suts_none_row:n {3} } }
    \tl_if_empty:NT \l__suts_uncov_tl { \tl_set:Nn \l__suts_uncov_tl { \__suts_none_row:n {2} } }
  }
\NewDocumentCommand \SpecTraceability {}
  {
    \__suts_build_trace:
    \section{Traceability}
    \subsection{Requirements~to~Test~Cases}
    \begin{xltabular}{\linewidth}{@{}L{2.6cm} Y L{4.5cm}@{}}
      \toprule
      \textbf{Requirement} & \textbf{Short~description} & \textbf{Test~cases} \\ \midrule
      \endhead
      \tl_use:N \l__suts_trace_tl
      \bottomrule
    \end{xltabular}
    \subsection{Uncovered~Requirements}\label{suts:uncovered}
    Requirements~allocated~to~the~unit~that~no~test~case~verifies:
    \begin{xltabular}{\linewidth}{@{}L{2.6cm} Y@{}}
      \toprule
      \textbf{Requirement} & \textbf{Rationale~/~verified~instead~by} \\ \midrule
      \tl_use:N \l__suts_uncov_tl
      \bottomrule
    \end{xltabular}
    \__suts_free:n { requirements }
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
