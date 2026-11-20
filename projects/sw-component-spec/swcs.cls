% =============================================================================
%  swcs.cls -- Software Component Specification (template / layout)
%
%  One document per software component: its requirements, its architecture
%  (units, interfaces, dynamic behaviour, resources) and its verification
%  (integration of its units, component tests). Covers the work products
%  expected by Automotive SPICE 4.0 SWE.2 (software architectural design) and
%  SWE.5 (software component verification and integration verification), and
%  ISO 26262-6 clauses 7 and 10; test documentation after ISO/IEC/IEEE 29119-3.
%  Spin-off of suts.cls (sw-unit-test-spec), same content model.
%
%  This file holds ALL formatting. Component content lives in
%  components/<component>/*.tex and uses only the input commands defined below
%  (no tables, no &, no \\). See README.md for the full command reference.
%
%  Class options are passed on to `article` (e.g. 10pt, letterpaper).
% =============================================================================
\NeedsTeXFormat{LaTeX2e}[2022-06-01]
\ProvidesClass{swcs}[2026/11/17 v0.1 Software Component Specification]

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
\RequirePackage{specfig}                % figures from data commands (spec-figures; sty/specfig*.sty)
% Project packages: packages.tex at the template root (optional, \usepackage only),
% read here so they load before underscore. Macros go to macros.tex (see \LoadContent).
\IfFileExists{./packages.tex}{\input{./packages.tex}}{}
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
\prop_new:N \g__swcs_meta_prop          % document / component metadata
\prop_new:N \g__swcs_text_prop          % prose blocks (scope, ...)
\cs_new_protected:Npn \__swcs_new_list:n #1
  { \tl_new:c { g__swcs_#1_tl } \int_new:c { g__swcs_#1_int } }
\cs_new_protected:Npn \__swcs_add:nn #1#2   % append a table row / list item
  { \tl_gput_right:cn { g__swcs_#1_tl } {#2} \int_gincr:c { g__swcs_#1_int } }
\cs_new:Npn \__swcs_rows:n #1 { \tl_use:c { g__swcs_#1_tl } }
\cs_new:Npn \__swcs_count:n #1 { \int_use:c { g__swcs_#1_int } }
\cs_new:Npn \__swcs_if_list_empty:nTF #1
  { \int_compare:nNnTF { \int_use:c { g__swcs_#1_int } } = 0 }
\clist_map_inline:nn
  { revisions, references, terms, provided, required, doubles, resources, config,
    methods, derivation, coverage, entry, exit, environment, deviations, covresults }
  { \__swcs_new_list:n {#1} }

% metadata getter: value or grey placeholder
\cs_new:Npn \__swcs_meta:n #1
  {
    \prop_if_in:NnTF \g__swcs_meta_prop {#1}
      { \prop_item:Nn \g__swcs_meta_prop {#1} } { \ph{#1} }
  }
\cs_new_protected:Npn \__swcs_text:nn #1#2   % prose or fallback
  {
    \prop_get:NnNTF \g__swcs_text_prop {#1} \l_tmpa_tl
      { \tl_use:N \l_tmpa_tl } {#2}
  }
% numbers get a percent sign: 100 -> 100 %, n.a. stays n.a.
\cs_new_protected:Npn \__swcs_pct:n #1
  {
    \regex_match:nnTF { \A\s*[0-9]+(\.[0-9]+)?\s*\Z } {#1}
      { #1\,\% } {#1}
  }
\cs_new:Npn \__swcs_none_row:n #1 { \multicolumn{#1}{@{}l}{\ph{none}} \\ }

% #3 := the IDs of clist #1, comma-separated, those not in prop #2 in red
\clist_new:N \l__swcs_ids_clist
\tl_new:N \l__swcs_ids_tl
\cs_new_protected:Npn \__swcs_check_ids:nNN #1#2#3
  {
    \clist_set:Nn \l__swcs_ids_clist {#1}
    \tl_clear:N #3
    \clist_map_inline:Nn \l__swcs_ids_clist
      {
        \tl_if_empty:NF #3 { \tl_put_right:Nn #3 { ,~ } }
        \prop_if_in:NnTF #2 {##1}
          { \tl_put_right:Nn #3 {##1} }
          { \tl_put_right:Nn #3 { \textcolor{warn}{##1~(unknown)} } }
      }
  }
\cs_generate_variant:Nn \__swcs_check_ids:nNN { VNN }

% =============================================================================
%  Input commands: metadata  (metadata.tex)
% =============================================================================
\clist_map_inline:nn
  { DocTitle, DocID, DocVersion, DocStatus, DocDate, ProjectName, Company,
    Author, Reviewer, Approver, ComponentName, ComponentBaseline, IntegrityLevel,
    SourceFiles, Language, ArchitectureReference }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { m }
      { \prop_gput:Nnn \g__swcs_meta_prop {#1} {##1} }
  }
\prop_gput:Nnn \g__swcs_meta_prop { DocTitle } { Software~Component~Specification }
\prop_gput:Nnn \g__swcs_meta_prop { DocDate } { \today }
\prop_gput:Nnn \g__swcs_meta_prop { DocStatus } { Draft }

% values for use in your own text
\NewDocumentCommand \TheComponent {} { \texttt{ \__swcs_meta:n { ComponentName } } }
\NewDocumentCommand \TheBaseline {} { \__swcs_meta:n { ComponentBaseline } }
\NewDocumentCommand \TheIntegrityLevel {} { \__swcs_meta:n { IntegrityLevel } }

% \Revision{version}{date}{author}{change}
\NewDocumentCommand \Revision { m m m +m }
  { \__swcs_add:nn { revisions } { #1 & #2 & #3 & #4 \\ } }

% =============================================================================
%  Input commands: introduction  (introduction.tex)
% =============================================================================
% Prose slots, each in two forms:
%   \Scope{text}                        plain text and paragraphs
%   \begin{Scope} ... \end{Scope}       any LaTeX (verbatim, listings, own
%                                       tables, %, &); \end{...} on its own line
% One macro serves both: called through \begin it starts the verbatim copy
% (see Free text below), otherwise it takes its argument. Given twice, the
% last one wins (warning).
\cs_new_protected:Npn \__swcs_text_set:nn #1#2
  {
    \bool_lazy_and:nnF
      { \str_if_eq_p:Vn \g__swcs_chapter_tl { testcases } }
      { ! \g__swcs_scan_bool }     % testcases.tex is read twice
      {
        \prop_if_in:NnT \g__swcs_text_prop {#1}
          { \msg_warning:nnn { swcs } { duplicate-text } {#1} }
      }
    \prop_gput:Nnn \g__swcs_text_prop {#1} {#2}
  }
\cs_generate_variant:Nn \__swcs_text_set:nn { nx }
\msg_new:nnn { swcs } { duplicate-text }
  { #1~given~more~than~once;~the~last~one~is~used. }
\clist_map_inline:nn
  { Purpose, Scope, UseCaseNote, FunctionalDescription, IntegrationStrategy,
    PassFailCriteria, ToolQualification, ResultsNote }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { }
      {
        \str_if_eq:VnTF \@currenvir {#1}
          { \__swcs_free_begin:n {#1} }
          { \__swcs_text_set:nn {#1} }
      }
    \cs_new_protected:cpn { end#1 }
      {
        \end{VerbatimOut}
        \__swcs_text_set:nx {#1}
          { \exp_not:N \file_input:n { \g__swcs_free_file_tl } \exp_not:N \unskip }
      }
  }

% \Reference{key}{internal | external}{document}{version}
%   numbered [R1], [R2], ... ; cite with \DocRef{key}
\prop_new:N \g__swcs_refnum_prop
\str_new:N \l__swcs_scope_str
\tl_new:N \l__swcs_scope_tl
\NewDocumentCommand \Reference { m m +m m }
  {
    \int_gincr:N \g__swcs_references_int
    \prop_gput:Nnx \g__swcs_refnum_prop {#1} { \int_use:N \g__swcs_references_int }
    \str_set:Nx \l__swcs_scope_str { \str_lowercase:n {#2} }
    \str_case:VnF \l__swcs_scope_str
      {
        {internal} { \tl_set:Nn \l__swcs_scope_tl { internal } }
        {int}      { \tl_set:Nn \l__swcs_scope_tl { internal } }
        {i}        { \tl_set:Nn \l__swcs_scope_tl { internal } }
        {external} { \tl_set:Nn \l__swcs_scope_tl { external } }
        {ext}      { \tl_set:Nn \l__swcs_scope_tl { external } }
        {e}        { \tl_set:Nn \l__swcs_scope_tl { external } }
      }
      {
        \msg_warning:nnnn { swcs } { bad-scope } {#1} {#2}
        \tl_set:Nn \l__swcs_scope_tl { \textcolor{warn}{#2} }
      }
    \tl_gput_right:Nx \g__swcs_references_tl
      {
        { [R\int_use:N \g__swcs_references_int] }
        \exp_not:n { & #3 & } \exp_not:V \l__swcs_scope_tl \exp_not:n { & #4 \\ }
      }
  }
\msg_new:nnn { swcs } { bad-scope }
  { \Reference{#1}:~'#2'~is~neither~'internal'~nor~'external'. }
\NewDocumentCommand \DocRef { m }
  {
    \prop_get:NnNTF \g__swcs_refnum_prop {#1} \l_tmpa_tl
      { [R\tl_use:N \l_tmpa_tl] }
      { \textcolor{warn}{[?#1]} \msg_warning:nnn { swcs } { unknown-ref } {#1} }
  }
\msg_new:nnn { swcs } { unknown-ref } { \DocRef{#1}:~no~\Reference{#1}{..}{..}~defined. }

% \Term{abbreviation}{definition}
\NewDocumentCommand \Term { m +m }
  { \__swcs_add:nn { terms } { #1 & #2 \\ } }

% =============================================================================
%  Input commands: component  (component.tex)
% =============================================================================
% \Unit{name}{responsibility}{unit verification, e.g. its unit test spec}
\seq_new:N \g__swcs_units_seq
\prop_new:N \g__swcs_unitidx_prop          % unit -> position (1, 2, ...)
\prop_new:N \g__swcs_unitresp_prop
\prop_new:N \g__swcs_unitver_prop
\NewDocumentCommand \Unit { m +m +m }
  {
    \prop_if_in:NnTF \g__swcs_unitidx_prop {#1}
      { \msg_warning:nnn { swcs } { duplicate-unit } {#1} }
      {
        \seq_gput_right:Nn \g__swcs_units_seq {#1}
        \prop_gput:Nnx \g__swcs_unitidx_prop {#1} { \seq_count:N \g__swcs_units_seq }
      }
    \prop_gput:Nnn \g__swcs_unitresp_prop {#1} {#2}
    \prop_gput:Nnn \g__swcs_unitver_prop {#1} {#3}
  }
\msg_new:nnn { swcs } { duplicate-unit } { Unit~#1~declared~twice. }

% \Allocate{unit}{REQ, REQ}   -- requirements realised by the unit
\prop_new:N \g__swcs_alloc_prop            % unit -> requirement IDs
\NewDocumentCommand \Allocate { m m }
  {
    \prop_get:NnNTF \g__swcs_alloc_prop {#1} \l_tmpa_tl
      { \tl_put_right:Nn \l_tmpa_tl { , #2 } }
      { \tl_set:Nn \l_tmpa_tl {#2} }
    \prop_gput:NnV \g__swcs_alloc_prop {#1} \l_tmpa_tl
  }

% \ProvidedInterface[unit]{name}{type / range / timing}{description}
%   [unit]: the unit that realises it (structure diagram, table)
\seq_new:N \g__swcs_provnames_seq          % all names, for the test harness
\prop_new:N \g__swcs_unitprov_prop         % unit -> interface names
\NewDocumentCommand \ProvidedInterface { o m m +m }
  {
    \seq_gput_right:Nn \g__swcs_provnames_seq {#2}
    \IfNoValueTF {#1}
      { \__swcs_add:nn { provided } { \texttt{#2} & -- & #3 & #4 \\ } }
      {
        \__swcs_add:nn { provided } { \texttt{#2} & \__swcs_unit_ref:n {#1} & #3 & #4 \\ }
        \prop_get:NnNTF \g__swcs_unitprov_prop {#1} \l_tmpa_tl
          { \tl_put_right:Nn \l_tmpa_tl { , #2 } }
          { \tl_set:Nn \l_tmpa_tl {#2} }
        \prop_gput:NnV \g__swcs_unitprov_prop {#1} \l_tmpa_tl
      }
  }
% a unit name; red if it is not declared with \Unit (checked when printed)
\cs_new_protected:Npn \__swcs_unit_ref:n #1
  {
    \prop_if_in:NnTF \g__swcs_unitidx_prop {#1}
      { \texttt{#1} } { \textcolor{warn}{\texttt{#1}~(unknown~unit)} }
  }

% \RequiredInterface[component]{name}{description}{replaced by}{behaviour in test}
%   [component]: the component that provides it (one box per component in the
%   diagrams; default: the name)
\seq_new:N \g__swcs_reqcomp_seq            % providing components, in order
\prop_new:N \g__swcs_reqfun_prop           % component -> interfaces
\prop_new:N \g__swcs_reqdbl_prop           % component -> replaced by
\NewDocumentCommand \RequiredInterface { o m +m m +m }
  {
    \tl_set:Nx \l_tmpb_tl { \IfNoValueTF {#1} { \exp_not:n {#2} } { \exp_not:n {#1} } }
    \tl_gput_right:Nx \g__swcs_required_tl
      { \exp_not:n { \texttt{#2} & } \exp_not:V \l_tmpb_tl \exp_not:n { & #3 \\ } }
    \int_gincr:N \g__swcs_required_int
    \__swcs_add:nn { doubles } { \texttt{#2} & #4 & #5 \\ }
    \seq_if_in:NVF \g__swcs_reqcomp_seq \l_tmpb_tl
      {
        \seq_gput_right:NV \g__swcs_reqcomp_seq \l_tmpb_tl
        \prop_gput:NVn \g__swcs_reqdbl_prop \l_tmpb_tl {#4}
      }
    \prop_get:NVNTF \g__swcs_reqfun_prop \l_tmpb_tl \l_tmpa_tl
      { \tl_put_right:Nn \l_tmpa_tl { ,~#2 } }
      { \tl_set:Nn \l_tmpa_tl {#2} }
    \prop_gput:NVV \g__swcs_reqfun_prop \l_tmpb_tl \l_tmpa_tl
  }

% \Uses{unit}{unit or component}{interfaces}   -- arrows of the structure diagram
\seq_new:N \g__swcs_uses_seq
\NewDocumentCommand \Uses { m m m }
  { \seq_gput_right:Nn \g__swcs_uses_seq { {#1} {#2} {#3} } }

% \Caller{component}{interfaces it uses}   -- left side of the context diagram
\seq_new:N \g__swcs_callers_seq
\NewDocumentCommand \Caller { m m }
  { \seq_gput_right:Nn \g__swcs_callers_seq { {#1} {#2} } }

% \Resource{resource}{budget}{verified by}
\NewDocumentCommand \Resource { m +m +m }
  { \__swcs_add:nn { resources } { #1 & #2 & #3 \\ } }
% \ConfigParameter{name}{values / default}{description}
\NewDocumentCommand \ConfigParameter { m +m +m }
  { \__swcs_add:nn { config } { \texttt{#1} & #2 & #3 \\ } }

% ---------------------------------------------------------------- diagrams ---
% Generic block diagram: left boxes -> centre box -> right boxes.
% Items of the side seqs: {name}{stereotype}{arrow label}{style}
\seq_new:N \l__swcs_left_seq
\seq_new:N \l__swcs_right_seq
\dim_new:N \l__swcs_step_dim
\dim_set:Nn \l__swcs_step_dim { 1.7cm }
\cs_new:Npn \__swcs_y:nnn #1#2#3   % y of item #2 of #3, spacing #1
  { \fp_to_dim:n { #1 * (#3 + 1 - 2 * #2) / 2 } }
\cs_new:Npn \__swcs_y:nn #1#2 { \__swcs_y:nnn { \l__swcs_step_dim } {#1} {#2} }
\cs_new_protected:Npn \__swcs_side:nnnnnnn #1#2#3#4#5#6#7
  % #1 L/R  #2 index  #3 count  #4 name  #5 stereotype  #6 label  #7 style
  {
    \node [ swcs/#7 ] (#1#2) at ( \str_if_eq:nnTF {#1} {L} { -7.4cm } { 7.4cm } , \__swcs_y:nn {#2} {#3} )
      {
        \tl_if_empty:nF {#5}
          { {\scriptsize\guillemotleft \text_lowercase:n {#5} \guillemotright} \\ }
        \textbf{#4}
      } ;
    \clist_set:Nn \l_tmpa_clist {#6}   % one interface per line
    \str_if_eq:nnTF {#1} {L}
      { \draw [ swcs/use ] (#1#2.east) -- (#1#2.east -| U.west) node [ swcs/lbl ] { \clist_use:Nn \l_tmpa_clist { \\ } } ; }
      { \draw [ swcs/use ] (#1#2.west -| U.east) -- (#1#2.west) node [ swcs/lbl ] { \clist_use:Nn \l_tmpa_clist { \\ } } ; }
  }
\cs_new_protected:Npn \__swcs_block_diagram:nnn #1#2#3
  % #1 centre stereotype  #2 centre text  #3 centre style
  {
    \int_set:Nn \l_tmpa_int
      { \int_max:nn { 1 } { \int_max:nn { \seq_count:N \l__swcs_left_seq } { \seq_count:N \l__swcs_right_seq } } }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \node [ swcs/#3 , minimum~height = \dim_eval:n { \l__swcs_step_dim * \l_tmpa_int - 0.3cm } ] (U) at (0,0)
        { {\scriptsize\guillemotleft#1\guillemotright} \\ #2 } ;
      \seq_map_indexed_inline:Nn \l__swcs_left_seq
        { \__swcs_side:nnnnnnn {L} {##1} { \seq_count:N \l__swcs_left_seq } ##2 }
      \seq_map_indexed_inline:Nn \l__swcs_right_seq
        { \__swcs_side:nnnnnnn {R} {##1} { \seq_count:N \l__swcs_right_seq } ##2 }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__swcs_right_from_required:n #1   % #1: true = show test doubles
  {
    \seq_clear:N \l__swcs_right_seq
    \seq_map_inline:Nn \g__swcs_reqcomp_seq
      {
        \prop_get:NnN \g__swcs_reqfun_prop {##1} \l_tmpa_tl
        \prop_get:NnN \g__swcs_reqdbl_prop {##1} \l_tmpb_tl
        \bool_if:nTF {#1}
          { \seq_put_right:Nx \l__swcs_right_seq { {##1} { \exp_not:V \l_tmpb_tl } { \exp_not:V \l_tmpa_tl } {double} } }
          { \seq_put_right:Nx \l__swcs_right_seq { {##1} {component} { \exp_not:V \l_tmpa_tl } {comp} } }
      }
  }
\cs_new_protected:Npn \__swcs_add_caller:nn #1#2
  { \seq_put_right:Nn \l__swcs_left_seq { {#1} {component} {#2} {comp} } }
% context: callers -> component -> providers of the required interfaces
\cs_new_protected:Npn \__swcs_context_diagram:
  {
    \seq_clear:N \l__swcs_left_seq
    \seq_map_inline:Nn \g__swcs_callers_seq { \__swcs_add_caller:nn ##1 }
    \__swcs_right_from_required:n { \c_false_bool }
    \__swcs_block_diagram:nnn { component } { \textbf{ \__swcs_meta:n { ComponentName } } } { cut }
  }
% harness: test driver -> component (its units real) -> test doubles
\cs_new_protected:Npn \__swcs_harness_diagram:
  {
    \seq_clear:N \l__swcs_left_seq
    \seq_put_right:Nx \l__swcs_left_seq
      { {Test~driver} {test} { \seq_use:Nn \g__swcs_provnames_seq { ,~ } } {driver} }
    \__swcs_right_from_required:n { \c_true_bool }
    \__swcs_block_diagram:nnn { CUT }
      {
        \textbf{ \__swcs_meta:n { ComponentName } }
        \seq_if_empty:NF \g__swcs_units_seq
          { \\[2pt] {\scriptsize\ttfamily \seq_use:Nn \g__swcs_units_seq { \\ } } }
      }
      { cut }
  }

% Internal structure: the units in a column inside the component boundary;
% provided interfaces enter from the left, unit -> unit uses run on lanes to
% the right of the units, uses of other components leave each unit at their
% own height, carry their label just outside the boundary and fan out to the
% component boxes on the right (ordered by the mean position of their users).
\seq_new:N \l__swcs_ext_seq
\prop_new:N \l__swcs_extidx_prop          % component -> box number
\prop_new:N \l__swcs_extsum_prop          % component -> sum of user positions
\prop_new:N \l__swcs_inn_prop             % component -> incoming arrows
\prop_new:N \l__swcs_ink_prop             %   ... drawn so far
\prop_new:N \l__swcs_outn_prop            % unit position -> outgoing arrows
\prop_new:N \l__swcs_outk_prop            %   ... drawn so far
\int_new:N \l__swcs_lanes_int
\int_new:N \l__swcs_lane_int
\tl_new:N \l__swcs_from_tl
\tl_new:N \l__swcs_to_tl
\tl_new:N \l__swcs_n_tl
\tl_new:N \l__swcs_dyout_tl
\tl_new:N \l__swcs_dyin_tl
\dim_new:N \l__swcs_ustep_dim
\dim_set:Nn \l__swcs_ustep_dim { 1.6cm }
\cs_new_protected:Npn \__swcs_prop_add:Nnn #1#2#3   % prop key += #3
  {
    \prop_get:NnNF #1 {#2} \l__swcs_n_tl { \tl_set:Nn \l__swcs_n_tl { 0 } }
    \prop_put:Nnx #1 {#2} { \int_eval:n { \l__swcs_n_tl + #3 } }
  }
\cs_generate_variant:Nn \__swcs_prop_add:Nnn { NV }
\cs_new_protected:Npn \__swcs_collect_use:nnn #1#2#3
  {
    \prop_get:NnNT \g__swcs_unitidx_prop {#1} \l__swcs_from_tl
      {
        \prop_if_in:NnTF \g__swcs_unitidx_prop {#2}
          { \int_incr:N \l__swcs_lanes_int }
          {
            \seq_if_in:NnF \l__swcs_ext_seq {#2} { \seq_put_right:Nn \l__swcs_ext_seq {#2} }
            \__swcs_prop_add:NnV \l__swcs_extsum_prop {#2} \l__swcs_from_tl
            \__swcs_prop_add:Nnn \l__swcs_inn_prop {#2} { 1 }
            \__swcs_prop_add:NVn \l__swcs_outn_prop \l__swcs_from_tl { 1 }
          }
      }
  }
\cs_generate_variant:Nn \__swcs_prop_add:Nnn { NnV }
% #3 := y offset of arrow number (prop #1 key #2, counted up) of all (prop #4 key #2)
\cs_new_protected:Npn \__swcs_offset:NnNN #1#2#3#4
  {
    \__swcs_prop_add:Nnn #1 {#2} { 1 }
    \tl_set:Nx #3
      {
        \__swcs_y:nnn { 0.36cm } { \prop_item:Nn #1 {#2} } { \prop_item:Nn #4 {#2} }
      }
  }
\cs_generate_variant:Nn \__swcs_offset:NnNN { NVNN }
\cs_new_protected:Npn \__swcs_draw_use:nnn #1#2#3
  {
    \clist_set:Nn \l_tmpa_clist {#3}
    \prop_get:NnNTF \g__swcs_unitidx_prop {#1} \l__swcs_from_tl
      {
        \prop_get:NnNTF \g__swcs_unitidx_prop {#2} \l__swcs_to_tl
          {
            \int_incr:N \l__swcs_lane_int
            \draw [ swcs/use ] (U\l__swcs_from_tl.east)
              -- ++( \dim_eval:n { 0.55cm * \l__swcs_lane_int } , 0 )
              |- node [ swcs/vlbl , pos = 0.25 ] { \clist_use:Nn \l_tmpa_clist { ,~ } }
              (U\l__swcs_to_tl.east) ;
          }
          {
            \prop_get:NnN \l__swcs_extidx_prop {#2} \l__swcs_to_tl
            \__swcs_offset:NVNN \l__swcs_outk_prop \l__swcs_from_tl \l__swcs_dyout_tl \l__swcs_outn_prop
            \__swcs_offset:NnNN \l__swcs_ink_prop {#2} \l__swcs_dyin_tl \l__swcs_inn_prop
            \draw [ swcs/use ]
              ($ (U\l__swcs_from_tl.east) + (0, \l__swcs_dyout_tl) $)
              -- ($ (B.east |- U\l__swcs_from_tl.east) + (5.2cm, \l__swcs_dyout_tl) $)
              -- ($ (E\l__swcs_to_tl.west) + (0, \l__swcs_dyin_tl) $) ;
            \node [ swcs/xlbl ] at ($ (B.east |- U\l__swcs_from_tl.east) + (0.1cm, \l__swcs_dyout_tl) $)
              { \clist_use:Nn \l_tmpa_clist { ,~ } } ;
          }
      }
      { \msg_warning:nnn { swcs } { unknown-uses } {#1} }
  }
\msg_new:nnn { swcs } { unknown-uses }
  { \Uses{#1}:~'#1'~is~not~declared~with~\Unit;~arrow~not~drawn. }
\cs_new_protected:Npn \__swcs_draw_provided:nn #1#2   % unit index, unit name
  {
    \prop_get:NnNT \g__swcs_unitprov_prop {#2} \l_tmpa_tl
      {
        \clist_set:NV \l_tmpa_clist \l_tmpa_tl
        \draw [ swcs/use ] (U#1.west) ++( -4.2cm , 0 ) -- (U#1.west)
          node [ swcs/plbl ] { \clist_use:Nn \l_tmpa_clist { \\ } } ;
      }
  }
\cs_new:Npn \__swcs_ext_mean:n #1
  { ( \prop_item:Nn \l__swcs_extsum_prop {#1} ) / ( \prop_item:Nn \l__swcs_inn_prop {#1} ) }
\cs_new_protected:Npn \__swcs_structure_diagram:
  {
    \seq_clear:N \l__swcs_ext_seq
    \clist_map_inline:nn { extidx, extsum, inn, ink, outn, outk }
      { \prop_clear:c { l__swcs_##1_prop } }
    \int_zero:N \l__swcs_lanes_int
    \int_zero:N \l__swcs_lane_int
    \seq_map_inline:Nn \g__swcs_uses_seq { \__swcs_collect_use:nnn ##1 }
    \seq_sort:Nn \l__swcs_ext_seq
      {
        \fp_compare:nNnTF { \__swcs_ext_mean:n {##1} } > { \__swcs_ext_mean:n {##2} }
          { \sort_return_swapped: } { \sort_return_same: }
      }
    \seq_map_indexed_inline:Nn \l__swcs_ext_seq { \prop_put:Nnn \l__swcs_extidx_prop {##2} {##1} }
    \int_set:Nn \l_tmpa_int { \seq_count:N \g__swcs_units_seq }
    \int_set:Nn \l_tmpb_int { \seq_count:N \l__swcs_ext_seq }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \seq_map_indexed_inline:Nn \g__swcs_units_seq
        {
          \node [ swcs/unit ] (U##1) at ( 0 , \__swcs_y:nnn { \l__swcs_ustep_dim } {##1} { \l_tmpa_int } )
            { {\scriptsize\guillemotleft unit\guillemotright} \\ \textbf{##2} } ;
        }
      \coordinate (Lane) at ( \dim_eval:n { 1.55cm + 0.55cm * \l__swcs_lanes_int + 0.3cm } , 0 ) ;
      \node [ swcs/boundary , fit = { (U1) (U\int_use:N \l_tmpa_int) (Lane) } , inner~ysep = 0.35cm ] (B) {} ;
      \node [ anchor = south , font = \small , align = center ] at (B.north)
        { {\scriptsize\guillemotleft component\guillemotright} \\ \textbf{ \__swcs_meta:n { ComponentName } } } ;
      \seq_map_indexed_inline:Nn \l__swcs_ext_seq
        {
          \node [ swcs/comp , anchor = west ] (E##1)
            at ( $ (B.east) + (6.4cm , \__swcs_y:nnn { \l__swcs_ustep_dim } {##1} { \l_tmpb_int }) $ )
            { {\scriptsize\guillemotleft component\guillemotright} \\ \textbf{##2} } ;
        }
      \seq_map_inline:Nn \g__swcs_uses_seq { \__swcs_draw_use:nnn ##1 }
      \seq_map_indexed_inline:Nn \g__swcs_units_seq { \__swcs_draw_provided:nn {##1} {##2} }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }

% use cases: \UseCase{use case}{actor, actor}
\seq_new:N \g__swcs_usecases_seq
\seq_new:N \g__swcs_actors_seq
\NewDocumentCommand \UseCase { m m }
  {
    \seq_gput_right:Nn \g__swcs_usecases_seq { {#1} {#2} }
    \clist_set:Nn \l_tmpa_clist {#2}
    \clist_map_inline:Nn \l_tmpa_clist
      { \seq_if_in:NnF \g__swcs_actors_seq {##1} { \seq_gput_right:Nn \g__swcs_actors_seq {##1} } }
  }
\cs_new_protected:Npn \__swcs_usecase_diagram:
  {
    \int_set:Nn \l_tmpa_int { \seq_count:N \g__swcs_usecases_seq }
    \int_set:Nn \l_tmpb_int { \seq_count:N \g__swcs_actors_seq }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \seq_map_indexed_inline:Nn \g__swcs_actors_seq
        {
          \pic (A##1) at ( -4.5cm , \__swcs_y:nnn { 2.4cm } {##1} { \l_tmpb_int } ) {swcs@actor={##2}} ;
        }
      \seq_map_indexed_inline:Nn \g__swcs_usecases_seq
        { \__swcs_usecase:nnnn {##1} { \l_tmpa_int } ##2 }
      \node [ swcs/boundary , fit = { (UC1) (UClast) } ] (B) {} ;
      \node [ anchor = south , font = \small , align = center ] at (B.north)
        { {\scriptsize\guillemotleft system\guillemotright} \\ \textbf{ \__swcs_meta:n { ProjectName } } } ;
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__swcs_usecase:nnnn #1#2#3#4   % index count name actors
  {
    \node [ swcs/usecase , alias = UClast ] (UC#1) at ( 3cm , \__swcs_y:nnn { 1.5cm } {#1} {#2} ) {#3} ;
    \clist_set:Nn \l_tmpa_clist {#4}
    \clist_map_inline:Nn \l_tmpa_clist
      {
        \seq_map_indexed_inline:Nn \g__swcs_actors_seq
          { \str_if_eq:nnT {##1} {####2} { \draw [ swcs/assoc ] (A####1-body) -- (UC#1) ; } }
      }
  }

% =============================================================================
%  Input commands: test approach  (approach.tex)
% =============================================================================
% \VerificationMethod{method}{yes|no}{remark}
\NewDocumentCommand \VerificationMethod { m m +m }
  {
    \__swcs_add:nn { methods }
      { #1 & \__swcs_check:n {#2} & #3 \\ }
  }
\cs_new:Npn \__swcs_check:n #1
  {
    \str_if_eq:eeTF { \str_lowercase:n {#1} } { yes } { $\boxtimes$ }
      { \str_if_eq:eeTF { \str_lowercase:n {#1} } { no } { $\square$ } {#1} }
  }
\NewDocumentCommand \DerivationTechnique { +m } { \__swcs_add:nn { derivation } { \item #1 } }
% \Coverage{metric}{target}{justification if not met}   -- target 100 -> 100 %
\NewDocumentCommand \Coverage { m m +m }
  { \__swcs_add:nn { coverage } { #1 & \__swcs_pct:n {#2} & #3 \\ } }
\NewDocumentCommand \EntryCriterion { +m } { \__swcs_add:nn { entry } { \item #1 } }
\NewDocumentCommand \ExitCriterion  { +m } { \__swcs_add:nn { exit }  { \item #1 } }

% \IntegrationStep{ID}{units integrated so far}{description}
%   test cases name their step with \Integration{ID}
\seq_new:N \g__swcs_steps_seq
\prop_new:N \g__swcs_stepunits_prop
\prop_new:N \g__swcs_stepdesc_prop
\prop_new:N \g__swcs_steptc_prop           % step -> linked test cases
\NewDocumentCommand \IntegrationStep { m m +m }
  {
    \prop_if_in:NnTF \g__swcs_stepunits_prop {#1}
      { \msg_warning:nnn { swcs } { duplicate-step } {#1} }
      { \seq_gput_right:Nn \g__swcs_steps_seq {#1} }
    \prop_gput:Nnn \g__swcs_stepunits_prop {#1} {#2}
    \prop_gput:Nnn \g__swcs_stepdesc_prop {#1} {#3}
  }
\msg_new:nnn { swcs } { duplicate-step } { Integration~step~#1~declared~twice. }

% =============================================================================
%  Input commands: test environment  (environment.tex)
% =============================================================================
% \Tool{item}{description}{version}
\NewDocumentCommand \Tool { m +m m }
  { \__swcs_add:nn { environment } { #1 & #2 & #3 \\ } }

% =============================================================================
%  Input commands: requirements  (requirements.tex)
% =============================================================================
% \SoftwareRequirement{ID}{functional | non-functional}{text}{source}
% \ComponentRequirement{ID}{functional | non-functional}{text}{derived from: ID, ID}
% \NotComponentTested{ID}{rationale / where it is verified instead}
\seq_new:N \g__swcs_req_seq
\prop_new:N \g__swcs_reqdesc_prop
\prop_new:N \g__swcs_reqlevel_prop       % S (software) / C (component)
\prop_new:N \g__swcs_reqkind_prop        % F / NF
\prop_new:N \g__swcs_reqsrc_prop         % source (S) or parent IDs (C)
\prop_new:N \g__swcs_reqchild_prop       % parent -> component children
\prop_new:N \g__swcs_reqtc_prop          % requirement -> linked test cases
\prop_new:N \g__swcs_reqnot_prop         % requirement -> rationale
\str_new:N \l__swcs_kind_str
\tl_new:N \l__swcs_kindv_tl
\cs_generate_variant:Nn \str_case:nnF { V }
\cs_new_protected:Npn \__swcs_req_add:nnnnn #1#2#3#4#5   % level ID kind text src
  {
    \prop_if_in:NnT \g__swcs_reqdesc_prop {#2}
      { \msg_warning:nnn { swcs } { duplicate-req } {#2} }
    \seq_gput_right:Nn \g__swcs_req_seq {#2}
    \prop_gput:Nnn \g__swcs_reqdesc_prop {#2} {#4}
    \prop_gput:Nnn \g__swcs_reqlevel_prop {#2} {#1}
    \prop_gput:Nnn \g__swcs_reqsrc_prop {#2} {#5}
    \str_set:Nx \l__swcs_kind_str { \str_lowercase:n {#3} }
    \str_case:VnF \l__swcs_kind_str
      {
        {functional}     { \tl_set:Nn \l__swcs_kindv_tl {F} }
        {f}              { \tl_set:Nn \l__swcs_kindv_tl {F} }
        {non-functional} { \tl_set:Nn \l__swcs_kindv_tl {NF} }
        {nonfunctional}  { \tl_set:Nn \l__swcs_kindv_tl {NF} }
        {nf}             { \tl_set:Nn \l__swcs_kindv_tl {NF} }
      }
      {   % unknown kind: warn, list it as functional
        \msg_warning:nnnn { swcs } { bad-kind } {#2} {#3}
        \tl_set:Nn \l__swcs_kindv_tl {F}
      }
    \prop_gput:NnV \g__swcs_reqkind_prop {#2} \l__swcs_kindv_tl
    \str_if_eq:nnT {#1} {C}
      {
        \clist_set:Nn \l_tmpa_clist {#5}
        \clist_map_inline:Nn \l_tmpa_clist
          {
            \prop_get:NnNTF \g__swcs_reqchild_prop {##1} \l_tmpa_tl
              { \tl_put_right:Nn \l_tmpa_tl { , #2 } }
              { \tl_set:Nn \l_tmpa_tl {#2} }
            \prop_gput:NnV \g__swcs_reqchild_prop {##1} \l_tmpa_tl
          }
      }
  }
\msg_new:nnn { swcs } { duplicate-req } { Requirement~#1~declared~twice. }
\msg_new:nnn { swcs } { bad-kind }
  { Requirement~#1:~kind~'#2'~is~neither~'functional'~nor~'non-functional';~listed~as~functional. }
\NewDocumentCommand \SoftwareRequirement { m m +m +m }
  { \__swcs_req_add:nnnnn {S} {#1} {#2} {#3} {#4} }
\NewDocumentCommand \ComponentRequirement { m m +m m }
  { \__swcs_req_add:nnnnn {C} {#1} {#2} {#3} {#4} }
\NewDocumentCommand \NotComponentTested { m +m }
  { \prop_gput:Nnn \g__swcs_reqnot_prop {#1} {#2} }

% =============================================================================
%  Input commands: test cases  (testcases.tex)
% =============================================================================
% \TestGroup{title}                         -- subsection heading
% \begin{TestCase}{ID}{title} fields... \end{TestCase}
%   fields (any order, all optional): \Objective \Verifies{REQ, REQ}
%   \Integration{step} \Method \Priority \Preconditions \InputData
%   \InputValue{name}{value}{class} \Step{action}{expected result}
%   \Postconditions \Implementation
%
% testcases.tex is read twice: in the preamble (scan: counts test cases and
% links requirements and integration steps, so tables work regardless of
% chapter order) and where \SpecTestCases is placed (render).
\bool_new:N \g__swcs_scan_bool
\int_new:N \g__swcs_tc_int
\seq_new:N \g__swcs_tc_seq
\clist_const:Nn \c__swcs_tcfields_clist
  { Objective, Verifies, Integration, Method, Priority, Preconditions, InputData,
    Postconditions, Implementation }
\clist_map_inline:Nn \c__swcs_tcfields_clist { \tl_new:c { g__swcs_tc_#1_tl } }
\tl_new:N \g__swcs_tc_steps_tl
\tl_new:N \g__swcs_tc_inputs_tl

\NewDocumentCommand \TestGroup { m }
  { \bool_if:NF \g__swcs_scan_bool { \subsection{#1} } }

\cs_new_protected:Npn \__swcs_tc_field:nn #1#2
  { \tl_gset:cn { g__swcs_tc_#1_tl } {#2} }

\NewDocumentEnvironment { TestCase } { m m +b }
  {
    \clist_map_inline:Nn \c__swcs_tcfields_clist { \tl_gclear:c { g__swcs_tc_##1_tl } }
    \tl_gclear:N \g__swcs_tc_steps_tl
    \tl_gclear:N \g__swcs_tc_inputs_tl
    \hbox_set:Nn \l_tmpa_box   % collect fields; stray text is discarded
      {
        \clist_map_inline:Nn \c__swcs_tcfields_clist
          { \cs_set_protected:cpn {##1} ####1 { \__swcs_tc_field:nn {##1} {####1} } }
        \cs_set_protected:Npn \Step ##1##2
          { \tl_gput_right:Nn \g__swcs_tc_steps_tl { \stepcounter{tcstepno} \thetcstepno & ##1 & ##2 \\ } }
        \cs_set_protected:Npn \InputValue ##1##2##3
          { \tl_gput_right:Nn \g__swcs_tc_inputs_tl { \texttt{##1} & ##2 & ##3 \\ } }
        #3
      }
    \bool_if:NTF \g__swcs_scan_bool
      { \__swcs_tc_scan:n {#1} }
      { \__swcs_tc_render:nn {#1} {#2} }
  }
  { }

% append the link to test case #1 to entry #3 of prop #2
\cs_new_protected:Npn \__swcs_link_tc:nNn #1#2#3
  {
    \prop_get:NnNF #2 {#3} \l_tmpa_tl { \tl_clear:N \l_tmpa_tl }
    \tl_if_empty:NF \l_tmpa_tl { \tl_put_right:Nn \l_tmpa_tl { ,~ } }
    \tl_put_right:Nn \l_tmpa_tl { \hyperref[tc:#1]{#1} }
    \prop_gput:NnV #2 {#3} \l_tmpa_tl
  }
\cs_new_protected:Npn \__swcs_tc_scan:n #1
  {
    \seq_if_in:NnT \g__swcs_tc_seq {#1}
      { \msg_warning:nnn { swcs } { duplicate-tc } {#1} }
    \seq_gput_right:Nn \g__swcs_tc_seq {#1}
    \int_gincr:N \g__swcs_tc_int
    \clist_set:NV \l_tmpa_clist \g__swcs_tc_Verifies_tl
    \clist_map_inline:Nn \l_tmpa_clist
      { \__swcs_link_tc:nNn {#1} \g__swcs_reqtc_prop {##1} }
    \clist_set:NV \l_tmpa_clist \g__swcs_tc_Integration_tl
    \clist_map_inline:Nn \l_tmpa_clist
      {
        \prop_if_in:NnF \g__swcs_stepunits_prop {##1}
          { \msg_warning:nnnn { swcs } { unknown-step } {#1} {##1} }
        \__swcs_link_tc:nNn {#1} \g__swcs_steptc_prop {##1}
      }
  }
\msg_new:nnn { swcs } { duplicate-tc } { Test~case~ID~#1~used~twice. }
\msg_new:nnn { swcs } { unknown-step }
  { Test~case~#1:~integration~step~#2~is~not~declared~with~\IntegrationStep. }

\newcounter{tcstepno}
\cs_new_protected:Npn \__swcs_tc_item:nn #1#2   % \item[label] field, if set
  {
    \tl_if_empty:cF { g__swcs_tc_#2_tl }
      { \item[#1] \tl_use:c { g__swcs_tc_#2_tl } }
  }
\cs_new_protected:Npn \__swcs_tc_render:nn #1#2
  {
    \addcontentsline{ltc}{testcase}{\protect\makebox[7em][l]{#1}#2}
    \begin{tcolorbox}[breakable, enhanced, colback=tcbg, colframe=accent,
        boxrule=0.6pt, arc=1.5pt, left=6pt, right=6pt,
        fonttitle=\bfseries, title={#1 \quad #2}]
    \phantomsection\label{tc:#1}
    \begin{description}[style=sameline, leftmargin=3.9cm, labelwidth=3.7cm,
                        font=\normalfont\bfseries\small, itemsep=1pt]
      \__swcs_tc_item:nn { Objective }     { Objective }
      \__swcs_tc_item:nn { Requirements }  { Verifies }
      \tl_if_empty:NF \g__swcs_tc_Integration_tl
        {
          \__swcs_check_ids:VNN \g__swcs_tc_Integration_tl \g__swcs_stepunits_prop \l__swcs_ids_tl
          \item[Integration~step] \tl_use:N \l__swcs_ids_tl
        }
      \__swcs_tc_item:nn { Method }        { Method }
      \__swcs_tc_item:nn { Priority }      { Priority }
      \__swcs_tc_item:nn { Preconditions } { Preconditions }
      \bool_lazy_and:nnF
        { \tl_if_empty_p:N \g__swcs_tc_InputData_tl }
        { \tl_if_empty_p:N \g__swcs_tc_inputs_tl }
        {
          \item[Input~data] \tl_use:N \g__swcs_tc_InputData_tl
          \tl_if_empty:NF \g__swcs_tc_inputs_tl
            {
              \tl_if_empty:NF \g__swcs_tc_InputData_tl { \par }
              \begin{tabular}[t]{@{}lll@{}} \tl_use:N \g__swcs_tc_inputs_tl \end{tabular}
            }
        }
      \tl_if_empty:NF \g__swcs_tc_steps_tl
        {
          \item[Test~steps]
          \setcounter{tcstepno}{0}
          \small
          \begin{tabularx}{\linewidth}[t]{@{}r L{0.42\linewidth} Y@{}}
            \# & \textbf{Action~/~Stimulus} & \textbf{Expected~result} \\ \midrule
            \tl_use:N \g__swcs_tc_steps_tl
            \bottomrule
          \end{tabularx}
        }
      \__swcs_tc_item:nn { Postconditions } { Postconditions }
      \__swcs_tc_item:nn { Implementation } { Implementation }
    \end{description}
    \end{tcolorbox}
  }

% =============================================================================
%  Input commands: results  (results.tex)
% =============================================================================
\clist_map_inline:nn { Executed, Passed, Failed }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { m }
      { \prop_gput:Nnn \g__swcs_meta_prop {#1} {##1} }
  }
% \CoverageResult{metric}{achieved}     -- 98 -> 98 %
\NewDocumentCommand \CoverageResult { m m }
  { \__swcs_add:nn { covresults } { #1~coverage & \__swcs_pct:n {#2} \\ } }
% \Deviation{ID}{test case}{description / justification}{status}
\NewDocumentCommand \Deviation { m m +m m }
  { \__swcs_add:nn { deviations } { #1 & #2 & #3 & #4 \\ } }

% =============================================================================
%  Free text  (any content file)
% =============================================================================
% \begin{FreeText} ... any LaTeX ... \end{FreeText}   (\end{FreeText} on its own line)
% The body is copied verbatim to \jobname.free-<file>-<n>.tex, so %, &, verbatim,
% listings, own tables all work. Placement: at the end of the chapter that the
% file belongs to; in testcases.tex (and in the main document body) exactly
% where it stands. Not inside a TestCase.
\tl_new:N \g__swcs_chapter_tl
\tl_gset:Nn \g__swcs_chapter_tl { inplace }
\int_new:N \g__swcs_free_int
\tl_new:N \g__swcs_free_file_tl
\cs_new_protected:Npn \__swcs_free_begin:n #1   % #1: target name
  {
    \int_gincr:N \g__swcs_free_int
    \tl_gset:Nx \g__swcs_free_file_tl
      { \c_sys_jobname_str .free- #1 - \int_use:N \g__swcs_free_int .tex }
    \VerbatimEnvironment
    \begin{VerbatimOut}{\g__swcs_free_file_tl}
  }
\cs_generate_variant:Nn \__swcs_free_begin:n { V }
\cs_new_protected:Npn \__swcs_free_register:n #1
  {
    \seq_if_exist:cF { g__swcs_free_#1_seq } { \seq_new:c { g__swcs_free_#1_seq } }
    \seq_gput_right:cV { g__swcs_free_#1_seq } \g__swcs_free_file_tl
  }
\newenvironment{FreeText}
  { \__swcs_free_begin:V \g__swcs_chapter_tl }
  {
    \end{VerbatimOut}
    \__swcs_free_done:
  }
% Named free-text blocks for fixed subsections (use them in design.tex or any
% content file except testcases.tex):
%   StaticArchitecture, DynamicBehavior, ErrorHandling
\clist_map_inline:nn { StaticArchitecture, DynamicBehavior, ErrorHandling }
  {
    \newenvironment{#1}
      { \__swcs_free_begin:n {#1} }
      {
        \end{VerbatimOut}
        \bool_lazy_or:nnTF
          { \str_if_eq_p:Vn \g__swcs_chapter_tl { testcases } }
          { \str_if_eq_p:Vn \g__swcs_chapter_tl { inplace } }
          { \msg_warning:nnn { swcs } { named-free-place } {#1} }
          { \__swcs_free_register:n {#1} }
      }
  }
\msg_new:nnn { swcs } { named-free-place }
  { #1~block~ignored:~put~it~into~a~content~file~such~as~design.tex~(not~testcases.tex). }
\cs_new_protected:Npn \__swcs_free_done:
  {
    \bool_lazy_or:nnTF
      { \str_if_eq_p:Vn \g__swcs_chapter_tl { testcases } }
      { \str_if_eq_p:Vn \g__swcs_chapter_tl { inplace } }
      { \bool_if:NF \g__swcs_scan_bool { \file_input:V \g__swcs_free_file_tl } }
      { \__swcs_free_register:V \g__swcs_chapter_tl }
  }
\cs_generate_variant:Nn \file_input:n { V }
\cs_generate_variant:Nn \__swcs_free_register:n { V }
% named block or placeholder
\cs_new_protected:Npn \__swcs_free_or_ph:nn #1#2
  {
    \seq_if_exist:cTF { g__swcs_free_#1_seq } { \__swcs_free:n {#1} }
      { \ph{#2~--~\string\begin\string{#1\string}~in~design.tex} }
  }
% place the free text blocks of content file #1
\cs_new_protected:Npn \__swcs_free:n #1
  {
    \seq_if_exist:cT { g__swcs_free_#1_seq }
      { \par \seq_map_inline:cn { g__swcs_free_#1_seq } { \file_input:n {##1} } }
  }

% =============================================================================
%  Loading content
% =============================================================================
% \LoadComponent{name}: loads the folder components/name (see \LoadContent).
%   Build-time override: if \SpecComponent is defined before the class, e.g.
%     latexmk -pdf -jobname=foo -usepretex='\def\SpecComponent{foo}' sw_component_spec.tex
%   it replaces name. A folder without metadata.tex gives a warning.
% \LoadContent{dir}: reads dir/{metadata,introduction,requirements,component,
%   design,approach,environment,results}.tex (missing files are skipped) and
%   scans dir/testcases.tex. Use in the preamble.
% Both set the search paths: component first, then the shared folders at root
%   figures: dir/figures/, figures/  (\includegraphics, \InputFigure)
%   code:    dir/code/,    code/     (\InputCode)
%   data:    dir/data/,    data/
%   data and code are also added to LaTeX's \input@path, so \input, \VerbatimInput,
%   \IfFileExists etc. find their files by name. \ComponentDir expands to dir.
\tl_new:N \g__swcs_dir_tl
\tl_new:N \l__swcs_found_tl
\cs_new:Npn \ComponentDir { \g__swcs_dir_tl }
\cs_new_protected:Npn \__swcs_input:n #1
  { \file_if_exist_input:nF { \g__swcs_dir_tl / #1 .tex } { } }
\cs_new_protected:Npn \__swcs_set_paths:
  {
    \use:x { \exp_not:N \graphicspath { { \g__swcs_dir_tl / figures/ } { figures/ } } }
    \cs_if_exist:NF \input@path { \tl_gset:Nn \input@path { } }
    \tl_gput_left:Nx \input@path
      { { \g__swcs_dir_tl / data/ } { \g__swcs_dir_tl / code/ } { data/ } { code/ } }
  }
% \__swcs_find:nnTF {kind}{file}: component folder first, then shared folder;
% the path found is in \l__swcs_found_tl.
% Names are turned into strings first: underscore makes _ active.
\tl_new:N \l__swcs_name_tl
\prg_new_protected_conditional:Npnn \__swcs_find:nn #1#2 { TF }
  {
    \tl_set:Nx \l__swcs_name_tl { \tl_to_str:n {#2} }
    \file_if_exist:nTF { \g__swcs_dir_tl / #1 / \l__swcs_name_tl }
      {
        \tl_set:Nx \l__swcs_found_tl { \g__swcs_dir_tl / #1 / \l__swcs_name_tl }
        \prg_return_true:
      }
      {
        \file_if_exist:nTF { #1 / \l__swcs_name_tl }
          { \tl_set:Nx \l__swcs_found_tl { #1 / \l__swcs_name_tl } \prg_return_true: }
          { \prg_return_false: }
      }
  }
\msg_new:nnn { swcs } { missing-file }
  { #1~`#2'~not~found~in~\g__swcs_dir_tl / #1/~nor~in~#1/. }
\msg_new:nnn { swcs } { missing-component }
  { Component~folder~`#1'~has~no~metadata.tex. }
\cs_new_protected:Npn \__swcs_missing:nn #1#2
  {
    \msg_warning:nnnn { swcs } { missing-file } {#1} {#2}
    \fbox { \textcolor{warn}{ missing~#1/#2 } }
  }
% \InputFigure[max width]{name}: figure code name.tex (a tikzpicture), typeset
% in the document (template colours, TikZ libraries, fonts apply); shrunk to
% max width (default \linewidth), never enlarged.
\NewDocumentCommand \InputFigure { O{\linewidth} m }
  {
    \__swcs_find:nnTF { figures } { #2 .tex }
      { \begin{adjustbox}{max~width=#1} \input{\l__swcs_found_tl} \end{adjustbox} }
      { \__swcs_missing:nn { figures } { #2 .tex } }
  }
% \InputCode[fancyvrb options]{file}: a source file from code/, verbatim.
\NewDocumentCommand \InputCode { O{} m }
  {
    \__swcs_find:nnTF { code } {#2}
      { \exp_args:NnV \__swcs_verbatim_input:nn {#1} \l__swcs_found_tl }
      { \__swcs_missing:nn { code } {#2} }
  }
\cs_new_protected:Npn \__swcs_verbatim_input:nn #1#2
  { \VerbatimInput [ fontsize = \small , #1 ] {#2} }
% Macro files: macros.tex at the template root (once), then dir/macros.tex,
% both optional, read before the content files; the folder's may \renewcommand.
\bool_new:N \g__swcs_root_macros_bool
\NewDocumentCommand \LoadContent { m }
  {
    \tl_gset:Nx \g__swcs_dir_tl { \tl_to_str:n {#1} }
    \typeout { swcs:~content~folder~`\g__swcs_dir_tl' }
    % root macros before the search paths: no data/ or code/ file of that name
    \bool_if:NF \g__swcs_root_macros_bool
      {
        \file_if_exist_input:n { ./macros.tex }
        \bool_gset_true:N \g__swcs_root_macros_bool
      }
    \__swcs_set_paths:
    \__swcs_input:n { macros }
    \clist_map_inline:nn
      { metadata, introduction, requirements, component, design, approach, environment, results }
      { \tl_gset:Nn \g__swcs_chapter_tl {##1} \__swcs_input:n {##1} }
    \bool_gset_true:N \g__swcs_scan_bool
    \tl_gset:Nn \g__swcs_chapter_tl { testcases }
    \__swcs_input:n { testcases }
    \bool_gset_false:N \g__swcs_scan_bool
    \tl_gset:Nn \g__swcs_chapter_tl { inplace }
  }
\NewDocumentCommand \LoadComponent { m }
  {
    \cs_if_exist:NTF \SpecComponent
      { \tl_set:Nx \l_tmpa_tl { components / \tl_to_str:N \SpecComponent } }
      { \tl_set:Nx \l_tmpa_tl { components / \tl_to_str:n {#1} } }
    \file_if_exist:nF { \l_tmpa_tl / metadata.tex }
      { \exp_args:NnnV \msg_warning:nnn { swcs } { missing-component } \l_tmpa_tl }
    \exp_args:NV \LoadContent \l_tmpa_tl
  }

% =============================================================================
%  Page layout
% =============================================================================
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\textbf{\__swcs_meta:n{DocTitle}}\\\small \__swcs_meta:n{ComponentName}}
\fancyhead[R]{\small \__swcs_meta:n{DocID}\ \textbar\ v\__swcs_meta:n{DocVersion}\\\small \__swcs_meta:n{DocStatus}}
\fancyfoot[L]{\small \__swcs_meta:n{Company}}
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
      {\Large \__swcs_meta:n{ProjectName}\par}
      \vspace{1cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{0.4cm}
      {\Huge\bfseries \__swcs_meta:n{DocTitle}\par}
      \vspace{0.3cm}
      {\Large Component:~\TheComponent\par}
      \vspace{0.4cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{2cm}
      \begin{tabular}{@{}ll@{}}
        \toprule
        Document~ID          & \__swcs_meta:n{DocID} \\
        Version              & \__swcs_meta:n{DocVersion} \\
        Status               & \__swcs_meta:n{DocStatus} \\
        Date                 & \__swcs_meta:n{DocDate} \\
        Component~baseline   & \__swcs_meta:n{ComponentBaseline} \\
        Integrity~level      & \__swcs_meta:n{IntegrityLevel} \\
        Author               & \__swcs_meta:n{Author} \\
        \bottomrule
      \end{tabular}
      \vfill
      {\small \__swcs_meta:n{Company}}
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
      \__swcs_if_list_empty:nTF { revisions } { \__swcs_none_row:n {4} } { \__swcs_rows:n { revisions } }
      \bottomrule
    \end{xltabular}
    \subsection*{Review~and~Approval}
    \begin{tabularx}{\linewidth}{@{}l L{4cm} X l@{}}
      \toprule
      \textbf{Role} & \textbf{Name} & \textbf{Signature} & \textbf{Date} \\ \midrule
      Author   & \__swcs_meta:n{Author}   & & \\
      Reviewer & \__swcs_meta:n{Reviewer} & & \\
      Approver & \__swcs_meta:n{Approver} & & \\
      \bottomrule
    \end{tabularx}
    \__swcs_free:n { metadata }
  }

\NewDocumentCommand \SpecContents {}
  { \tableofcontents \listoftestcases \clearpage }

\NewDocumentCommand \SpecIntroduction {}
  {
    \section{Introduction}
    \subsection{Purpose}
    \__swcs_text:nn { Purpose }
      {
        This~document~specifies~the~software~component~\TheComponent{}:~the~software~
        requirements~allocated~to~it,~its~architecture~(units,~interfaces,~dynamic~behaviour,~
        resources)~and~its~verification,~that~is~the~integration~of~its~units~and~the~test~cases~
        that~verify~the~component~against~its~requirements~and~its~architecture.
      }
    \subsection{Scope}
    \__swcs_text:nn { Scope } { \ph{Scope} }
    \seq_if_empty:NF \g__swcs_usecases_seq
      {
        \subsection{Stakeholders~and~Use~Cases}
        \__swcs_text:nn { UseCaseNote } { }
        \__swcs_usecase_diagram:
      }
    \subsection{References}
    \begin{xltabular}{\linewidth}{@{}l Y l l@{}}
      \toprule
      \textbf{ID} & \textbf{Document} & \textbf{Type} & \textbf{Version} \\ \midrule
      \__swcs_if_list_empty:nTF { references } { \__swcs_none_row:n {4} } { \__swcs_rows:n { references } }
      \bottomrule
    \end{xltabular}
    \subsection{Terms~and~Abbreviations}
    \begin{xltabular}{\linewidth}{@{}l Y@{}}
      \toprule
      \textbf{Term} & \textbf{Definition} \\ \midrule
      \__swcs_if_list_empty:nTF { terms } { \__swcs_none_row:n {2} } { \__swcs_rows:n { terms } }
      \bottomrule
    \end{xltabular}
    \__swcs_free:n { introduction }
  }

% rows of the units table, built before the table (no loops inside cells)
\tl_new:N \l__swcs_unitrows_tl
\cs_new_protected:Npn \__swcs_build_unit_rows:
  {
    \tl_clear:N \l__swcs_unitrows_tl
    \seq_map_inline:Nn \g__swcs_units_seq
      {
        \prop_get:NnNTF \g__swcs_alloc_prop {##1} \l_tmpb_tl
          { \__swcs_check_ids:VNN \l_tmpb_tl \g__swcs_reqdesc_prop \l__swcs_ids_tl }
          { \tl_set:Nn \l__swcs_ids_tl { -- } }
        \prop_get:NnN \g__swcs_unitresp_prop {##1} \l_tmpa_tl
        \prop_get:NnN \g__swcs_unitver_prop {##1} \l_tmpb_tl
        \tl_put_right:Nx \l__swcs_unitrows_tl
          {
            \exp_not:n { \texttt{##1} & } \exp_not:V \l_tmpa_tl & \exp_not:V \l__swcs_ids_tl
            & \exp_not:V \l_tmpb_tl \exp_not:N \\
          }
      }
    \prop_map_inline:Nn \g__swcs_alloc_prop   % allocated to an undeclared unit
      {
        \prop_if_in:NnF \g__swcs_unitidx_prop {##1}
          {
            \tl_put_right:Nn \l__swcs_unitrows_tl
              { \textcolor{warn}{\texttt{##1}} & \textcolor{warn}{not~declared~with~\string\Unit} & ##2 & \\ }
          }
      }
    \tl_if_empty:NT \l__swcs_unitrows_tl { \tl_set:Nn \l__swcs_unitrows_tl { \__swcs_none_row:n {4} } }
  }
\NewDocumentCommand \SpecDescription {}
  {
    \section{Component~Description}
    \subsection{Identification}
    \begin{tabularx}{\linewidth}{@{}L{4.4cm} Y@{}}
      \toprule
      Component~name          & \TheComponent \\
      Baseline                & \__swcs_meta:n{ComponentBaseline} \\
      Source~files            & \__swcs_meta:n{SourceFiles} \\
      Language                & \__swcs_meta:n{Language} \\
      Integrity~level         & \__swcs_meta:n{IntegrityLevel} \\
      Architecture~reference  & \__swcs_meta:n{ArchitectureReference} \\
      \bottomrule
    \end{tabularx}
    \subsection{Functional~Description}
    \__swcs_text:nn { FunctionalDescription } { \ph{FunctionalDescription} }
    \bool_lazy_and:nnF
      { \seq_if_empty_p:N \g__swcs_callers_seq }
      { \seq_if_empty_p:N \g__swcs_reqcomp_seq }
      {
        \subsection{Context}
        Neighbours~of~\TheComponent{}:~its~users~(left)~and~the~components~providing~its~
        required~interfaces~(right).
        \__swcs_context_diagram:
      }
    \subsection{Static~Architecture}\label{swcs:static}
    \__swcs_build_unit_rows:
    Units~of~\TheComponent{}~and~the~requirements~allocated~to~them:
    \begin{xltabular}{\linewidth}{@{}L{2.9cm} Y L{2.7cm} L{3.3cm}@{}}
      \toprule
      \textbf{Unit} & \textbf{Responsibility} & \textbf{Allocated} & \textbf{Unit~verification} \\ \midrule
      \endhead
      \tl_use:N \l__swcs_unitrows_tl
      \bottomrule
    \end{xltabular}
    \seq_if_empty:NF \g__swcs_units_seq
      {
        Internal~structure:~provided~interfaces~(left),~use~relations~between~the~units~
        and~to~other~components~(right).
        \__swcs_structure_diagram:
      }
    \__swcs_free_or_ph:nn { StaticArchitecture } { static~architecture }
    \Needspace{6\baselineskip}
    \subsection{Interfaces}
    \subsubsection{Provided~Interfaces}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{2.6cm} L{2.6cm} Y@{}}
      \toprule
      \textbf{Interface} & \textbf{Realised~by} & \textbf{Type~/~Range} & \textbf{Description} \\ \midrule
      \endhead
      \__swcs_if_list_empty:nTF { provided } { \__swcs_none_row:n {4} } { \__swcs_rows:n { provided } }
      \bottomrule
    \end{xltabular}
    \Needspace{6\baselineskip}
    \subsubsection{Required~Interfaces}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{2.6cm} Y@{}}
      \toprule
      \textbf{Interface} & \textbf{Provided~by} & \textbf{Description} \\ \midrule
      \endhead
      \__swcs_if_list_empty:nTF { required } { \__swcs_none_row:n {3} } { \__swcs_rows:n { required } }
      \bottomrule
    \end{xltabular}
    \subsection{Dynamic~Behavior}
    \__swcs_free_or_ph:nn { DynamicBehavior } { dynamic~behavior }
    \subsection{Error~Handling}
    \__swcs_free_or_ph:nn { ErrorHandling } { error~handling }
    \Needspace{6\baselineskip}
    \subsection{Resource~Budgets}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{3.4cm} Y@{}}
      \toprule
      \textbf{Resource} & \textbf{Budget} & \textbf{Verified~by} \\ \midrule
      \__swcs_if_list_empty:nTF { resources } { \__swcs_none_row:n {3} } { \__swcs_rows:n { resources } }
      \bottomrule
    \end{xltabular}
    \Needspace{6\baselineskip}
    \subsection{Configuration~Parameters}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{3.4cm} Y@{}}
      \toprule
      \textbf{Parameter} & \textbf{Values~/~Default} & \textbf{Description} \\ \midrule
      \__swcs_if_list_empty:nTF { config } { \__swcs_none_row:n {3} } { \__swcs_rows:n { config } }
      \bottomrule
    \end{xltabular}
    \__swcs_free:n { component }
    \__swcs_free:n { design }
  }

\cs_new_protected:Npn \__swcs_itemize:n #1
  {
    \__swcs_if_list_empty:nTF {#1} { \ph{none} }
      { \begin{itemize}[nosep] \__swcs_rows:n {#1} \end{itemize} }
  }
% rows of the integration steps table; units not integrated in any step
\tl_new:N \l__swcs_steprows_tl
\tl_new:N \l__swcs_notint_tl
\seq_new:N \l__swcs_intunits_seq
\cs_new_protected:Npn \__swcs_build_step_rows:
  {
    \tl_clear:N \l__swcs_steprows_tl
    \seq_clear:N \l__swcs_intunits_seq
    \seq_map_inline:Nn \g__swcs_steps_seq
      {
        \prop_get:NnN \g__swcs_stepunits_prop {##1} \l_tmpb_tl
        \__swcs_check_ids:VNN \l_tmpb_tl \g__swcs_unitidx_prop \l__swcs_ids_tl
        \clist_set:NV \l_tmpa_clist \l_tmpb_tl
        \clist_map_inline:Nn \l_tmpa_clist
          { \seq_if_in:NnF \l__swcs_intunits_seq {####1} { \seq_put_right:Nn \l__swcs_intunits_seq {####1} } }
        \prop_get:NnN \g__swcs_stepdesc_prop {##1} \l_tmpa_tl
        \tl_put_right:Nx \l__swcs_steprows_tl
          {
            \exp_not:n {##1} & { \exp_not:N \ttfamily \exp_not:V \l__swcs_ids_tl } &
            \exp_not:V \l_tmpa_tl \exp_not:N \\
          }
      }
    \tl_if_empty:NT \l__swcs_steprows_tl { \tl_set:Nn \l__swcs_steprows_tl { \__swcs_none_row:n {3} } }
    \tl_clear:N \l__swcs_notint_tl
    \seq_if_empty:NF \g__swcs_steps_seq
      {
        \seq_map_inline:Nn \g__swcs_units_seq
          {
            \seq_if_in:NnF \l__swcs_intunits_seq {##1}
              {
                \tl_if_empty:NF \l__swcs_notint_tl { \tl_put_right:Nn \l__swcs_notint_tl { ,~ } }
                \tl_put_right:Nn \l__swcs_notint_tl { \texttt{##1} }
              }
          }
      }
  }
\NewDocumentCommand \SpecTestApproach {}
  {
    \section{Test~Approach}
    \subsection{Verification~Methods}
    Methods~applied~to~this~component~(ISO~26262-6~Table~10~/~ASPICE~SWE.5):
    \begin{xltabular}{\linewidth}{@{}Y c L{6cm}@{}}
      \toprule
      \textbf{Method} & \textbf{Applied} & \textbf{Remark} \\ \midrule
      \__swcs_if_list_empty:nTF { methods } { \__swcs_none_row:n {3} } { \__swcs_rows:n { methods } }
      \bottomrule
    \end{xltabular}
    \subsection{Integration~Strategy}
    \__swcs_text:nn { IntegrationStrategy } { \ph{IntegrationStrategy} }
    \__swcs_build_step_rows:
    \par Integration~steps~(each~step~lists~all~units~integrated~so~far;~test~cases~name~their~step):
    \begin{xltabular}{\linewidth}{@{}l L{5cm} Y@{}}
      \toprule
      \textbf{Step} & \textbf{Integrated~units} & \textbf{Description} \\ \midrule
      \endhead
      \tl_use:N \l__swcs_steprows_tl
      \bottomrule
    \end{xltabular}
    \tl_if_empty:NF \l__swcs_notint_tl
      { \par \textcolor{warn}{Units~not~integrated~in~any~step:~\l__swcs_notint_tl} }
    \subsection{Test~Case~Derivation}
    Test~cases~are~derived~using~(ISO~26262-6~Table~11):
    \__swcs_itemize:n { derivation }
    \subsection{Structural~Coverage~Targets}
    Coverage~at~the~software~architectural~level~(ISO~26262-6~Table~12): \par
    \begin{tabularx}{\linewidth}{@{}l c Y@{}}
      \toprule
      \textbf{Metric} & \textbf{Target} & \textbf{Justification~if~not~met} \\ \midrule
      \__swcs_if_list_empty:nTF { coverage } { \__swcs_none_row:n {3} } { \__swcs_rows:n { coverage } }
      \bottomrule
    \end{tabularx}
    \subsection{Entry~and~Exit~Criteria}
    \textbf{Entry:} \__swcs_itemize:n { entry }
    \textbf{Exit:}  \__swcs_itemize:n { exit }
    \subsection{Pass/Fail~Criteria}
    \__swcs_text:nn { PassFailCriteria } { \ph{PassFailCriteria} }
    \__swcs_free:n { approach }
  }

\NewDocumentCommand \SpecTestEnvironment {}
  {
    \section{Test~Environment}
    \seq_if_empty:NF \g__swcs_reqcomp_seq
      {
        Test~harness:~the~test~driver~calls~the~provided~interfaces~of~the~component~under~
        test~(CUT),~whose~units~are~all~real;~only~its~required~interfaces~are~replaced~by~test~doubles.
        \__swcs_harness_diagram:
      }
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} Y l@{}}
      \toprule
      \textbf{Item} & \textbf{Description} & \textbf{Version} \\ \midrule
      \__swcs_if_list_empty:nTF { environment } { \__swcs_none_row:n {3} } { \__swcs_rows:n { environment } }
      \bottomrule
    \end{xltabular}
    \par \__swcs_text:nn { ToolQualification } { }
    \Needspace{6\baselineskip}
    \subsection{Test~Doubles}
    \begin{xltabular}{\linewidth}{@{}L{4.2cm} L{2.6cm} Y@{}}
      \toprule
      \textbf{Required~interface} & \textbf{Replaced~by} & \textbf{Behaviour~in~test} \\ \midrule
      \__swcs_if_list_empty:nTF { doubles } { \__swcs_none_row:n {3} } { \__swcs_rows:n { doubles } }
      \bottomrule
    \end{xltabular}
    \__swcs_free:n { environment }
  }

\NewDocumentCommand \SpecTestCases {}
  {
    \section{Test~Cases}
    \tl_gset:Nn \g__swcs_chapter_tl { testcases }
    \__swcs_input:n { testcases }
    \tl_gset:Nn \g__swcs_chapter_tl { inplace }
  }

% rows are built before the tables (no loops inside alignment cells)
\tl_new:N \l__swcs_trace_tl
\tl_new:N \l__swcs_uncov_tl
\tl_new:N \l__swcs_steptrace_tl
\tl_new:N \l__swcs_rows_tl
\tl_new:N \l__swcs_a_tl
\tl_new:N \l__swcs_b_tl
\tl_new:N \l__swcs_c_tl
\tl_new:N \l__swcs_d_tl
\tl_new:N \l__swcs_k_tl
\clist_new:N \l__swcs_c_clist
% #2 := how requirement #1 is verified: its own test cases, and for a
% software requirement also "via" its verified component requirements
\cs_new_protected:Npn \__swcs_req_verified:nN #1#2
  {
    \prop_get:NnNF \g__swcs_reqtc_prop {#1} #2 { \tl_clear:N #2 }
    \prop_get:NnNT \g__swcs_reqchild_prop {#1} \l__swcs_c_tl
      {
        \tl_clear:N \l__swcs_d_tl
        \clist_set:NV \l__swcs_c_clist \l__swcs_c_tl
        \clist_map_inline:Nn \l__swcs_c_clist
          {
            \prop_if_in:NnT \g__swcs_reqtc_prop {##1}
              {
                \tl_if_empty:NF \l__swcs_d_tl { \tl_put_right:Nn \l__swcs_d_tl { ,~ } }
                \tl_put_right:Nn \l__swcs_d_tl {##1}
              }
          }
        \tl_if_empty:NF \l__swcs_d_tl
          {
            \tl_if_empty:NF #2 { \tl_put_right:Nn #2 { ;~ } }
            \tl_put_right:Nn #2 { via~ }
            \tl_put_right:NV #2 \l__swcs_d_tl
          }
      }
  }
\cs_new:Npn \__swcs_kind_label:n #1
  {
    \str_if_eq:eeTF { \prop_item:Nn \g__swcs_reqlevel_prop {#1} } { S } { software } { component } ,~
    \str_if_eq:eeTF { \prop_item:Nn \g__swcs_reqkind_prop {#1} } { NF } { non-functional } { functional }
  }
\cs_new_protected:Npn \__swcs_build_trace:
  {
    \tl_clear:N \l__swcs_trace_tl
    \tl_clear:N \l__swcs_uncov_tl
    \seq_map_inline:Nn \g__swcs_req_seq
      {
        \prop_get:NnN \g__swcs_reqdesc_prop {##1} \l__swcs_a_tl
        \__swcs_req_verified:nN {##1} \l__swcs_b_tl
        \tl_if_empty:NT \l__swcs_b_tl
          {
            \tl_set:Nn \l__swcs_b_tl { \textit{none~--~see~\ref{swcs:uncovered}} }
            \prop_get:NnNF \g__swcs_reqnot_prop {##1} \l__swcs_c_tl
              {
                \prop_get:NnNTF \g__swcs_reqchild_prop {##1} \l__swcs_d_tl
                  {   % software requirement: rationale lies with its derived requirements
                    \clist_set:NV \l__swcs_c_clist \l__swcs_d_tl
                    \tl_set:Nx \l__swcs_c_tl
                      { via~derived~\clist_use:Nn \l__swcs_c_clist { ,~ }~--~see~their~rationale }
                  }
                  { \tl_set:Nn \l__swcs_c_tl { \textcolor{warn}{rationale~missing~(add~\string\NotComponentTested)} } }
              }
            \tl_put_right:Nx \l__swcs_uncov_tl
              { \exp_not:n {##1} & \exp_not:V \l__swcs_c_tl \exp_not:N \\ }
          }
        \tl_put_right:Nx \l__swcs_trace_tl
          {
            \exp_not:n {##1} & { \exp_not:N \footnotesize \__swcs_kind_label:n {##1} } &
            \exp_not:V \l__swcs_a_tl & \exp_not:V \l__swcs_b_tl \exp_not:N \\
          }
      }
    \prop_map_inline:Nn \g__swcs_reqtc_prop   % verified but never declared
      {
        \prop_if_in:NnF \g__swcs_reqdesc_prop {##1}   % prop keys compare as strings
          {
            \tl_put_right:Nn \l__swcs_trace_tl
              { ##1 & & \textcolor{warn}{not~declared~in~requirements.tex} & ##2 \\ }
          }
      }
    \tl_if_empty:NT \l__swcs_trace_tl { \tl_set:Nn \l__swcs_trace_tl { \__swcs_none_row:n {4} } }
    \tl_if_empty:NT \l__swcs_uncov_tl { \tl_set:Nn \l__swcs_uncov_tl { \__swcs_none_row:n {2} } }
    % integration steps -> test cases
    \tl_clear:N \l__swcs_steptrace_tl
    \seq_map_inline:Nn \g__swcs_steps_seq
      {
        \prop_get:NnN \g__swcs_stepunits_prop {##1} \l__swcs_a_tl
        \prop_get:NnNF \g__swcs_steptc_prop {##1} \l__swcs_b_tl
          { \tl_set:Nn \l__swcs_b_tl { \textcolor{warn}{none~(add~a~test~case~with~\string\Integration)} } }
        \tl_put_right:Nx \l__swcs_steptrace_tl
          {
            \exp_not:n {##1} & { \exp_not:N \ttfamily \exp_not:V \l__swcs_a_tl } &
            \exp_not:V \l__swcs_b_tl \exp_not:N \\
          }
      }
    \prop_map_inline:Nn \g__swcs_steptc_prop   % referenced but never declared
      {
        \prop_if_in:NnF \g__swcs_stepunits_prop {##1}
          {
            \tl_put_right:Nn \l__swcs_steptrace_tl
              { ##1 & \textcolor{warn}{not~declared~in~approach.tex} & ##2 \\ }
          }
      }
    \tl_if_empty:NT \l__swcs_steptrace_tl { \tl_set:Nn \l__swcs_steptrace_tl { \__swcs_none_row:n {3} } }
  }
% rows of one requirements table: level #1 (S/C), kind #2 (F/NF)
\cs_new_protected:Npn \__swcs_req_rows:nn #1#2
  {
    \tl_clear:N \l__swcs_rows_tl
    \seq_map_inline:Nn \g__swcs_req_seq
      {
        \bool_lazy_and:nnT
          { \str_if_eq_p:ee { \prop_item:Nn \g__swcs_reqlevel_prop {##1} } {#1} }
          { \str_if_eq_p:ee { \prop_item:Nn \g__swcs_reqkind_prop {##1} } {#2} }
          {
            \prop_get:NnN \g__swcs_reqdesc_prop {##1} \l__swcs_a_tl
            \prop_get:NnN \g__swcs_reqsrc_prop {##1} \l__swcs_k_tl
            \str_if_eq:nnT {#1} {C}   % parents: unknown IDs in red
              {
                \__swcs_check_ids:VNN \l__swcs_k_tl \g__swcs_reqdesc_prop \l__swcs_ids_tl
                \tl_set_eq:NN \l__swcs_k_tl \l__swcs_ids_tl
                \tl_if_empty:NT \l__swcs_k_tl { \tl_set:Nn \l__swcs_k_tl { -- } }
              }
            \__swcs_req_verified:nN {##1} \l__swcs_b_tl
            \tl_if_empty:NT \l__swcs_b_tl
              { \tl_set:Nn \l__swcs_b_tl { \textit{not~component~tested~(\ref{swcs:uncovered})} } }
            \tl_put_right:Nx \l__swcs_rows_tl
              {
                \exp_not:n {##1} & \exp_not:V \l__swcs_a_tl & \exp_not:V \l__swcs_k_tl &
                \exp_not:V \l__swcs_b_tl \exp_not:N \\
              }
          }
      }
    \tl_if_empty:NT \l__swcs_rows_tl { \tl_set:Nn \l__swcs_rows_tl { \__swcs_none_row:n {4} } }
  }
\cs_new_protected:Npn \__swcs_req_table:nnn #1#2#3   % level kind third-column header
  {
    \__swcs_req_rows:nn {#1} {#2}
    \begin{xltabular}{\linewidth}{@{}L{2.1cm} Y L{2.6cm} L{3.2cm}@{}}
      \toprule
      \textbf{ID} & \textbf{Requirement} & \textbf{#3} & \textbf{Verified~by} \\ \midrule
      \endhead
      \tl_use:N \l__swcs_rows_tl
      \bottomrule
    \end{xltabular}
  }
\NewDocumentCommand \SpecRequirements {}
  {
    \section{Requirements}
    Software~requirements~are~allocated~to~\TheComponent{}~from~the~software~requirements~
    specification;~component~requirements~are~derived~from~them~or~from~the~architecture~
    (interfaces,~timing,~resources).~Both~are~verified~by~the~component~test~cases;~a~software~
    requirement~also~counts~as~verified~via~its~verified~component~requirements.~Their~
    allocation~to~the~units~is~shown~in~section~\ref{swcs:static}.
    \Needspace{8\baselineskip}
    \subsection{Software~Requirements}
    \subsubsection{Functional}
    \__swcs_req_table:nnn {S} {F} {Source}
    \Needspace{6\baselineskip}
    \subsubsection{Non-Functional}
    \__swcs_req_table:nnn {S} {NF} {Source}
    \Needspace{8\baselineskip}
    \subsection{Component~Requirements}
    \subsubsection{Functional}
    \__swcs_req_table:nnn {C} {F} {Derived~from}
    \Needspace{6\baselineskip}
    \subsubsection{Non-Functional}
    \__swcs_req_table:nnn {C} {NF} {Derived~from}
    \__swcs_free:n { requirements }
  }
\NewDocumentCommand \SpecTraceability {}
  {
    \__swcs_build_trace:
    \section{Traceability}
    \Needspace{8\baselineskip}
    \subsection{Requirements~to~Test~Cases}
    \begin{xltabular}{\linewidth}{@{}L{2.5cm} L{2.2cm} Y L{3.6cm}@{}}
      \toprule
      \textbf{Requirement} & \textbf{Type} & \textbf{Description} & \textbf{Test~cases} \\ \midrule
      \endhead
      \tl_use:N \l__swcs_trace_tl
      \bottomrule
    \end{xltabular}
    \Needspace{6\baselineskip}
    \subsection{Uncovered~Requirements}\label{swcs:uncovered}
    Requirements~that~no~test~case~verifies~(directly~or,~for~software~requirements,~via~component~ones):
    \begin{xltabular}{\linewidth}{@{}L{2.5cm} Y@{}}
      \toprule
      \textbf{Requirement} & \textbf{Rationale~/~verified~instead~by} \\ \midrule
      \tl_use:N \l__swcs_uncov_tl
      \bottomrule
    \end{xltabular}
    \Needspace{6\baselineskip}
    \subsection{Integration~Steps~to~Test~Cases}
    \begin{xltabular}{\linewidth}{@{}l L{5cm} Y@{}}
      \toprule
      \textbf{Step} & \textbf{Integrated~units} & \textbf{Test~cases} \\ \midrule
      \endhead
      \tl_use:N \l__swcs_steptrace_tl
      \bottomrule
    \end{xltabular}
  }

\NewDocumentCommand \SpecResults {}
  {
    \section{Test~Results~Summary}
    \__swcs_text:nn { ResultsNote } { } \par
    \begin{tabularx}{\linewidth}{@{}Y r@{}}
      \toprule
      Test~cases~specified       & \int_use:N \g__swcs_tc_int \\
      Executed~/~Passed~/~Failed & \__swcs_meta:n{Executed}~/~\__swcs_meta:n{Passed}~/~\__swcs_meta:n{Failed} \\
      \__swcs_rows:n { covresults }
      Deviations                 & \__swcs_count:n { deviations } \\
      \bottomrule
    \end{tabularx}
    \subsection{Deviations}
    \begin{xltabular}{\linewidth}{@{}l L{3cm} Y l@{}}
      \toprule
      \textbf{ID} & \textbf{Test~case} & \textbf{Description~/~Justification} & \textbf{Status} \\ \midrule
      \__swcs_if_list_empty:nTF { deviations } { \__swcs_none_row:n {4} } { \__swcs_rows:n { deviations } }
      \bottomrule
    \end{xltabular}
    \__swcs_free:n { results }
  }
\ExplSyntaxOff

% ------------------------------------------------------------ diagram styles ---
\colorlet{swcsunit}{accent!12}
\colorlet{swcsdouble}{orange!15}
\tikzset{
  swcs/box/.style   = {draw=accent, rectangle, align=center, font=\small,
                       text width=2.9cm, minimum height=1.1cm, inner sep=3pt,
                       execute at begin node={\lefthyphenmin=62 }}, % no word hyphenation, breaks after _ stay
  swcs/comp/.style  = {swcs/box, fill=white},
  swcs/driver/.style= {swcs/box, fill=swcsdouble},
  swcs/double/.style= {swcs/box, fill=swcsdouble, dashed},
  swcs/cut/.style   = {swcs/box, fill=swcsunit, very thick, text width=3.4cm},
  swcs/unit/.style  = {swcs/box, fill=swcsunit, minimum height=1.0cm},
  swcs/use/.style   = {-{Stealth[open]}, dashed, accent},
  swcs/lbl/.style   = {midway, above, font=\scriptsize\ttfamily, align=center},
  swcs/plbl/.style  = {pos=0.45, above, font=\scriptsize\ttfamily, align=center},
  swcs/xlbl/.style  = {anchor=south west, inner sep=1pt, text=accent, font=\scriptsize\ttfamily},
  swcs/vlbl/.style  = {rotate=90, anchor=north, inner sep=1.5pt, font=\scriptsize\ttfamily},
  swcs/usecase/.style = {draw=accent, ellipse, fill=swcsunit, align=center,
                       font=\small, text width=3.6cm, inner sep=1pt, minimum height=1.1cm},
  swcs/boundary/.style= {draw=accent, rectangle, inner sep=8pt},
  swcs/assoc/.style = {accent},
  swcs@actor/.pic   = {
    \draw[accent, thick] (0,0.45) circle (0.15)
      (0,0.3) -- (0,-0.1) (-0.25,0.15) -- (0.25,0.15)
      (0,-0.1) -- (-0.2,-0.45) (0,-0.1) -- (0.2,-0.45);
    \coordinate (-body) at (0.3,0.1);
    \node[below, font=\small, align=center, text width=2.6cm] at (0,-0.5) {#1};
  },
}
\endinput
