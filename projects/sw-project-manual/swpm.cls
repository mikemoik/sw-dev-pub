% =============================================================================
%  swpm.cls -- Software Project Manual (template / layout)
%
%  One document per project that develops one software component: who does
%  what (organisation), which process is followed and how it is tailored,
%  milestones and releases, work products and reviews, configuration and
%  change management, quality assurance, risks, tools -- plus a developer
%  manual (engineering rules, CI pipeline, Definition of Done, how-tos)
%  and the open point list (generated from an export, e.g. by an LLM).
%  Covers the plans expected by Automotive SPICE 4.0 MAN.3, MAN.5, SUP.1,
%  SUP.8, SUP.9 and SUP.10. Sister of swcs.cls (sw-component-spec) and
%  suts.cls (sw-unit-test-spec), same content model.
%
%  This file holds ALL formatting. Project content lives in
%  manuals/<manual>/*.tex and uses only the input commands defined below
%  (no tables, no &, no \\). See README.md for the command reference.
%
%  Class options are passed on to `article` (e.g. 10pt, letterpaper).
% =============================================================================
\NeedsTeXFormat{LaTeX2e}[2022-06-01]
\ProvidesClass{swpm}[2026/11/17 v0.1 Software Project Manual]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[11pt,a4paper]{article}

% ---------------------------------------------------------------- packages ---
\RequirePackage[T1]{fontenc}
\RequirePackage{lmodern}
\PassOptionsToPackage{table}{xcolor}   % \rowcolor (top-5 open points); before tikz,
\RequirePackage{tikz}                  % which loads xcolor itself on older pgf
\usetikzlibrary{arrows.meta,positioning,fit,calc,shapes.geometric}
\RequirePackage{microtype}
\DisableLigatures[-]{family=tt*}      % --preset stays two hyphens in code
\RequirePackage[margin=2.2cm,headheight=28pt]{geometry}
\RequirePackage{xcolor}
\RequirePackage{booktabs}
\RequirePackage{tabularx}
\RequirePackage{xltabular}             % tabularx that breaks across pages
\RequirePackage{array}
\RequirePackage{enumitem}
\RequirePackage{fancyhdr}
\RequirePackage{lastpage}
\RequirePackage{amsmath}
\RequirePackage{amssymb}
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
\RequirePackage[strings,nohyphen]{underscore} % plain _ in text: heater_ctrl

% ---------------------------------------------------------------- styling ---
\definecolor{accent}{HTML}{1F4E79}
\definecolor{tcbg}{HTML}{F4F7FB}
\definecolor{phgray}{HTML}{8A8A8A}
\definecolor{warn}{HTML}{B00020}
\definecolor{risklow}{HTML}{D9EAD3}
\definecolor{riskmed}{HTML}{FFF2CC}
\definecolor{riskhigh}{HTML}{F4CCCC}
\definecolor{optop}{HTML}{FFF2CC}       % top-5 open points in the status lists

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
\prop_new:N \g__swpm_meta_prop          % document / project metadata
\prop_new:N \g__swpm_text_prop          % prose blocks (scope, ...)
% simple lists: rows are complete when the command is read (no checks)
\cs_new_protected:Npn \__swpm_new_list:n #1
  { \tl_new:c { g__swpm_#1_tl } \int_new:c { g__swpm_#1_int } }
\cs_new_protected:Npn \__swpm_add:nn #1#2
  { \tl_gput_right:cn { g__swpm_#1_tl } {#2} \int_gincr:c { g__swpm_#1_int } }
\cs_new:Npn \__swpm_rows:n #1 { \tl_use:c { g__swpm_#1_tl } }
\cs_new:Npn \__swpm_if_list_empty:nTF #1
  { \int_compare:nNnTF { \int_use:c { g__swpm_#1_int } } = 0 }
\clist_map_inline:nn
  { revisions, references, terms, objectives, configitems, baselines, naming,
    metrics, done }
  { \__swpm_new_list:n {#1} }
% checked lists: the raw data is kept as {arg}{arg}... items of a seq; rows
% are built when the chapter is printed, so every ID of every file is known
% and the order of the content files does not matter
\clist_map_inline:nn
  { members, stakeholders, meetings, deliverables, releases, reviews,
    qa, rules, cistages, workflows, howtos }
  { \seq_new:c { g__swpm_#1_seq } }

% metadata getter: value or grey placeholder
\cs_new:Npn \__swpm_meta:n #1
  {
    \prop_if_in:NnTF \g__swpm_meta_prop {#1}
      { \prop_item:Nn \g__swpm_meta_prop {#1} } { \ph{#1} }
  }
\cs_new_protected:Npn \__swpm_text:nn #1#2   % prose or fallback
  {
    \prop_get:NnNTF \g__swpm_text_prop {#1} \l_tmpa_tl
      { \tl_use:N \l_tmpa_tl } {#2}
  }
\cs_new:Npn \__swpm_none_row:n #1 { \multicolumn{#1}{@{}l}{\ph{none}} \\ }
\cs_new:Npn \__swpm_dash:n #1 { \tl_if_blank:nTF {#1} { -- } {#1} }
\cs_new_protected:Npn \__swpm_warn:n #1 { \textcolor{warn}{#1} }

\tl_new:N \l__swpm_rows_tl
\tl_new:N \l__swpm_head_tl
\tl_new:N \l__swpm_spec_tl
\tl_new:N \l__swpm_tmp_tl
\tl_new:N \l__swpm_a_tl
\tl_new:N \l__swpm_b_tl
\tl_new:N \l__swpm_c_tl
\tl_new:N \l__swpm_d_tl
\tl_new:N \l__swpm_x_tl
\clist_new:N \l__swpm_ids_clist
\clist_new:N \l__swpm_x_clist

% key #2 of prop #1 += ", #3" (lists of names or IDs)
\cs_new_protected:Npn \__swpm_prop_append:Nnn #1#2#3
  {
    \prop_get:NnNTF #1 {#2} \l__swpm_tmp_tl
      { \tl_put_right:Nn \l__swpm_tmp_tl { ,~ #3 } }
      { \tl_set:Nn \l__swpm_tmp_tl {#3} }
    \prop_gput:NnV #1 {#2} \l__swpm_tmp_tl
  }

% #4 := the IDs of clist #1, comma-separated; IDs not in prop #2 in red,
% marked "(unknown #3)"
\cs_new_protected:Npn \__swpm_check:nNnN #1#2#3#4
  {
    \clist_set:Nn \l__swpm_ids_clist {#1}
    \tl_clear:N #4
    \clist_map_inline:Nn \l__swpm_ids_clist
      {
        \tl_if_empty:NF #4 { \tl_put_right:Nn #4 { ,~ } }
        \prop_if_in:NnTF #2 {##1}
          { \tl_put_right:Nn #4 {##1} }
          { \tl_put_right:Nn #4 { \__swpm_warn:n {##1~(unknown~#3)} } }
      }
  }
\cs_generate_variant:Nn \__swpm_check:nNnN { VNnN }
% as above, but an empty list is an error: red "#3 missing"
\cs_new_protected:Npn \__swpm_check_req:nNnN #1#2#3#4
  {
    \__swpm_check:nNnN {#1} #2 {#3} #4
    \tl_if_empty:NT #4 { \tl_set:Nn #4 { \__swpm_warn:n {#3~missing} } }
  }
% as above, an empty list prints --
\cs_new_protected:Npn \__swpm_check_opt:nNnN #1#2#3#4
  {
    \__swpm_check:nNnN {#1} #2 {#3} #4
    \tl_if_empty:NT #4 { \tl_set:Nn #4 { -- } }
  }

% one table: column spec, number of columns, header cells, rows tl
% (rows are built before the table: no loops inside alignment cells)
\cs_new_protected:Npn \__swpm_table:nnnN #1#2#3#4
  {
    \tl_if_empty:NT #4 { \tl_set:Nn #4 { \__swpm_none_row:n {#2} } }
    \begin{xltabular}{\linewidth}{#1}
      \toprule
      #3 \\ \midrule
      \endhead
      \tl_use:N #4
      \bottomrule
    \end{xltabular}
  }
% the same for a simple list
\cs_new_protected:Npn \__swpm_list_table:nnnn #1#2#3#4
  {
    \tl_set:Nx \l__swpm_rows_tl
      { \__swpm_if_list_empty:nTF {#4} { } { \exp_not:v { g__swpm_#4_tl } } }
    \__swpm_table:nnnN {#1} {#2} {#3} \l__swpm_rows_tl
  }
\cs_new_protected:Npn \__swpm_itemize:n #1
  {
    \__swpm_if_list_empty:nTF {#1} { \ph{none} }
      { \begin{itemize}[nosep] \__swpm_rows:n {#1} \end{itemize} }
  }
\msg_new:nnn { swpm } { duplicate } { #1~#2~declared~twice. }

% yes / no -> yes / no; anything else as written
\cs_new:Npn \__swpm_yesno:n #1
  {
    \str_if_eq:eeTF { \str_lowercase:n {#1} } { yes } { yes }
      { \str_if_eq:eeTF { \str_lowercase:n {#1} } { no } { no } {#1} }
  }

% =============================================================================
%  Input commands: metadata  (metadata.tex)
% =============================================================================
\clist_map_inline:nn
  { DocTitle, DocID, DocVersion, DocStatus, DocDate, ProjectName, ProjectID,
    Customer, Company, Author, Reviewer, Approver, ComponentName,
    IntegrityLevel, ProjectStart, ProjectEnd, Repository }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { m }
      { \prop_gput:Nnn \g__swpm_meta_prop {#1} {##1} }
  }
\prop_gput:Nnn \g__swpm_meta_prop { DocTitle } { Software~Project~Manual }
\prop_gput:Nnn \g__swpm_meta_prop { DocDate } { \today }
\prop_gput:Nnn \g__swpm_meta_prop { DocStatus } { Draft }

% values for use in your own text
\NewDocumentCommand \TheComponent {} { \texttt{ \__swpm_meta:n { ComponentName } } }
\NewDocumentCommand \TheProject {} { \__swpm_meta:n { ProjectName } }
\NewDocumentCommand \TheIntegrityLevel {} { \__swpm_meta:n { IntegrityLevel } }

% \Revision{version}{date}{author}{change}
\NewDocumentCommand \Revision { m m m +m }
  { \__swpm_add:nn { revisions } { #1 & #2 & #3 & #4 \\ } }

% =============================================================================
%  Free text  (any content file)
% =============================================================================
% \begin{FreeText} ... any LaTeX ... \end{FreeText}   (\end{FreeText} on its own line)
% The body is copied verbatim to \jobname.free-<file>-<n>.tex, so %, &, verbatim,
% listings, own tables all work. Placement: at the end of the chapter of the
% file it is in; in the main document body exactly where it stands.
\tl_new:N \g__swpm_chapter_tl
\tl_gset:Nn \g__swpm_chapter_tl { inplace }
\int_new:N \g__swpm_free_int
\tl_new:N \g__swpm_free_file_tl
\cs_new_protected:Npn \__swpm_free_begin:n #1   % #1: target name
  {
    \int_gincr:N \g__swpm_free_int
    \tl_gset:Nx \g__swpm_free_file_tl
      { \c_sys_jobname_str .free- #1 - \int_use:N \g__swpm_free_int .tex }
    \VerbatimEnvironment
    \begin{VerbatimOut}{\g__swpm_free_file_tl}
  }
\cs_generate_variant:Nn \__swpm_free_begin:n { V }
\cs_new_protected:Npn \__swpm_free_register:n #1
  {
    \seq_if_exist:cF { g__swpm_free_#1_seq } { \seq_new:c { g__swpm_free_#1_seq } }
    \seq_gput_right:cV { g__swpm_free_#1_seq } \g__swpm_free_file_tl
  }
\cs_generate_variant:Nn \__swpm_free_register:n { V }
\cs_generate_variant:Nn \file_input:n { V }
\newenvironment{FreeText}
  { \__swpm_free_begin:V \g__swpm_chapter_tl }
  {
    \end{VerbatimOut}
    \str_if_eq:VnTF \g__swpm_chapter_tl { inplace }
      { \file_input:V \g__swpm_free_file_tl }
      { \__swpm_free_register:V \g__swpm_chapter_tl }
  }
% place the free text blocks of content file #1
\cs_new_protected:Npn \__swpm_free:n #1
  {
    \seq_if_exist:cT { g__swpm_free_#1_seq }
      { \par \seq_map_inline:cn { g__swpm_free_#1_seq } { \file_input:n {##1} } }
  }

% Prose slots, each in two forms:
%   \Scope{text}                        plain text and paragraphs
%   \begin{Scope} ... \end{Scope}       any LaTeX (verbatim, own tables, %, &);
%                                       \end{...} on its own line
% Given twice, the last one wins (warning).
\cs_new_protected:Npn \__swpm_text_set:nn #1#2
  {
    \prop_if_in:NnT \g__swpm_text_prop {#1}
      { \msg_warning:nnn { swpm } { duplicate-text } {#1} }
    \prop_gput:Nnn \g__swpm_text_prop {#1} {#2}
  }
\cs_generate_variant:Nn \__swpm_text_set:nn { nx }
\msg_new:nnn { swpm } { duplicate-text }
  { #1~given~more~than~once;~the~last~one~is~used. }
\clist_map_inline:nn
  { Purpose, Scope, Communication, ProcessReference, BranchingModel,
    ReleaseProcedure, Escalation, ToolQualification }
  {
    \exp_args:Nc \NewDocumentCommand {#1} { }
      {
        \str_if_eq:VnTF \@currenvir {#1}
          { \__swpm_free_begin:n {#1} }
          { \__swpm_text_set:nn {#1} }
      }
    \cs_new_protected:cpn { end#1 }
      {
        \end{VerbatimOut}
        \__swpm_text_set:nx {#1}
          { \exp_not:N \file_input:n { \g__swpm_free_file_tl } \exp_not:N \unskip }
      }
  }

% =============================================================================
%  Input commands: introduction  (introduction.tex)
% =============================================================================
% \Reference{key}{internal | external}{document}{version}
%   numbered [R1], [R2], ... ; cite with \DocRef{key}
\prop_new:N \g__swpm_refnum_prop
\str_new:N \l__swpm_scope_str
\tl_new:N \l__swpm_scope_tl
\NewDocumentCommand \Reference { m m +m m }
  {
    \int_gincr:N \g__swpm_references_int
    \prop_gput:Nnx \g__swpm_refnum_prop {#1} { \int_use:N \g__swpm_references_int }
    \str_set:Nx \l__swpm_scope_str { \str_lowercase:n {#2} }
    \str_case:VnF \l__swpm_scope_str
      {
        {internal} { \tl_set:Nn \l__swpm_scope_tl { internal } }
        {int}      { \tl_set:Nn \l__swpm_scope_tl { internal } }
        {i}        { \tl_set:Nn \l__swpm_scope_tl { internal } }
        {external} { \tl_set:Nn \l__swpm_scope_tl { external } }
        {ext}      { \tl_set:Nn \l__swpm_scope_tl { external } }
        {e}        { \tl_set:Nn \l__swpm_scope_tl { external } }
      }
      {
        \msg_warning:nnnn { swpm } { bad-scope } {#1} {#2}
        \tl_set:Nn \l__swpm_scope_tl { \textcolor{warn}{#2} }
      }
    \tl_gput_right:Nx \g__swpm_references_tl
      {
        { [R\int_use:N \g__swpm_references_int] }
        \exp_not:n { & #3 & } \exp_not:V \l__swpm_scope_tl \exp_not:n { & #4 \\ }
      }
  }
\cs_generate_variant:Nn \str_case:nnF { V }
\msg_new:nnn { swpm } { bad-scope }
  { \Reference{#1}:~'#2'~is~neither~'internal'~nor~'external'. }
\NewDocumentCommand \DocRef { m }
  {
    \prop_get:NnNTF \g__swpm_refnum_prop {#1} \l_tmpa_tl
      { [R\tl_use:N \l_tmpa_tl] }
      { \textcolor{warn}{[?#1]} \msg_warning:nnn { swpm } { unknown-ref } {#1} }
  }
\msg_new:nnn { swpm } { unknown-ref } { \DocRef{#1}:~no~\Reference{#1}{..}{..}~defined. }

% \Term{abbreviation}{definition}
\NewDocumentCommand \Term { m +m }
  { \__swpm_add:nn { terms } { #1 & #2 \\ } }
% \ProjectObjective{text}
\NewDocumentCommand \ProjectObjective { +m }
  { \__swpm_add:nn { objectives } { \item #1 } }
% \Deliverable{item}{recipient}{milestone}
\NewDocumentCommand \Deliverable { +m m m }
  { \seq_gput_right:Nn \g__swpm_deliverables_seq { {#1} {#2} {#3} } }

% =============================================================================
%  Input commands: organization  (organization.tex)
% =============================================================================
% \Role[reports to]{ID}{name}{responsibility}
\seq_new:N \g__swpm_roles_seq
\prop_new:N \g__swpm_role_prop             % ID -> name
\prop_new:N \g__swpm_roleidx_prop          % ID -> 1, 2, ...
\prop_new:N \g__swpm_roleresp_prop
\prop_new:N \g__swpm_roleparent_prop
\prop_new:N \g__swpm_rolemembers_prop      % ID -> member names
\NewDocumentCommand \Role { o m m +m }
  {
    \prop_if_in:NnTF \g__swpm_role_prop {#2}
      { \msg_warning:nnnn { swpm } { duplicate } { Role } {#2} }
      {
        \seq_gput_right:Nn \g__swpm_roles_seq {#2}
        \prop_gput:Nnx \g__swpm_roleidx_prop {#2} { \seq_count:N \g__swpm_roles_seq }
      }
    \prop_gput:Nnn \g__swpm_role_prop {#2} {#3}
    \prop_gput:Nnn \g__swpm_roleresp_prop {#2} {#4}
    \IfNoValueF {#1} { \prop_gput:Nnn \g__swpm_roleparent_prop {#2} {#1} }
  }
% \Member{name}{role IDs}{organisation / contact}
\NewDocumentCommand \Member { m m +m }
  {
    \seq_gput_right:Nn \g__swpm_members_seq { {#1} {#2} {#3} }
    \clist_set:Nn \l__swpm_x_clist {#2}
    \clist_map_inline:Nn \l__swpm_x_clist
      { \__swpm_prop_append:Nnn \g__swpm_rolemembers_prop {##1} {#1} }
  }
% \Stakeholder{name}{interest / interface}{contact role}
\NewDocumentCommand \Stakeholder { m +m m }
  { \seq_gput_right:Nn \g__swpm_stakeholders_seq { {#1} {#2} {#3} } }
% \Meeting{meeting}{cadence}{participant roles}{purpose / output}
\NewDocumentCommand \Meeting { m m m +m }
  { \seq_gput_right:Nn \g__swpm_meetings_seq { {#1} {#2} {#3} {#4} } }

% =============================================================================
%  Input commands: lifecycle  (lifecycle.tex)
% =============================================================================
% \Process{ID}{name}{yes | no | tailored}{rationale}
\seq_new:N \g__swpm_procs_seq
\prop_new:N \g__swpm_proc_prop             % ID -> name
\prop_new:N \g__swpm_procscope_prop        % ID -> Y / N / T / ?
\prop_new:N \g__swpm_procrat_prop
\str_new:N \l__swpm_s_str
\NewDocumentCommand \Process { m m m +m }
  {
    \prop_if_in:NnTF \g__swpm_proc_prop {#1}
      { \msg_warning:nnnn { swpm } { duplicate } { Process } {#1} }
      { \seq_gput_right:Nn \g__swpm_procs_seq {#1} }
    \prop_gput:Nnn \g__swpm_proc_prop {#1} {#2}
    \prop_gput:Nnn \g__swpm_procrat_prop {#1} {#4}
    \str_set:Nx \l__swpm_s_str { \str_lowercase:n {#3} }
    \str_case:VnF \l__swpm_s_str
      {
        {yes}      { \prop_gput:Nnn \g__swpm_procscope_prop {#1} {Y} }
        {no}       { \prop_gput:Nnn \g__swpm_procscope_prop {#1} {N} }
        {tailored} { \prop_gput:Nnn \g__swpm_procscope_prop {#1} {T} }
      }
      {
        \msg_warning:nnnn { swpm } { bad-proc } {#1} {#3}
        \prop_gput:Nnn \g__swpm_procscope_prop {#1} {?}
      }
  }
\msg_new:nnn { swpm } { bad-proc }
  { \Process{#1}:~'#2'~is~not~'yes',~'no'~or~'tailored'. }
% \Milestone{ID}{date YYYY-MM-DD}{name}{exit criteria: work product IDs}
\seq_new:N \g__swpm_ms_seq
\prop_new:N \g__swpm_ms_prop               % ID -> name
\prop_new:N \g__swpm_msdate_prop
\prop_new:N \g__swpm_mscrit_prop
\NewDocumentCommand \Milestone { m m +m m }
  {
    \prop_if_in:NnTF \g__swpm_ms_prop {#1}
      { \msg_warning:nnnn { swpm } { duplicate } { Milestone } {#1} }
      { \seq_gput_right:Nn \g__swpm_ms_seq {#1} }
    \prop_gput:Nnn \g__swpm_ms_prop {#1} {#3}
    \prop_gput:Nnn \g__swpm_msdate_prop {#1} {#2}
    \prop_gput:Nnn \g__swpm_mscrit_prop {#1} {#4}
  }
% \Release{version}{date YYYY-MM-DD}{content}{milestone}
\NewDocumentCommand \Release { m m +m m }
  { \seq_gput_right:Nn \g__swpm_releases_seq { {#1} {#2} {#3} {#4} } }

% =============================================================================
%  Input commands: work products  (workproducts.tex)
% =============================================================================
% \WorkProduct{ID}{name}{process IDs}{responsible role}{template / location}
\seq_new:N \g__swpm_wps_seq
\prop_new:N \g__swpm_wp_prop               % ID -> name
\prop_new:N \g__swpm_wpproc_prop
\prop_new:N \g__swpm_wpresp_prop
\prop_new:N \g__swpm_wptpl_prop
\prop_new:N \g__swpm_wprev_prop            % ID -> reviewer roles (all reviews)
\prop_new:N \g__swpm_wpappr_prop           % ID -> approver role
\prop_new:N \g__swpm_wpinf_prop            % ID -> informed roles
\NewDocumentCommand \WorkProduct { m +m m m +m }
  {
    \prop_if_in:NnTF \g__swpm_wp_prop {#1}
      { \msg_warning:nnnn { swpm } { duplicate } { Work~product } {#1} }
      { \seq_gput_right:Nn \g__swpm_wps_seq {#1} }
    \prop_gput:Nnn \g__swpm_wp_prop {#1} {#2}
    \prop_gput:Nnn \g__swpm_wpproc_prop {#1} {#3}
    \prop_gput:Nnn \g__swpm_wpresp_prop {#1} {#4}
    \prop_gput:Nnn \g__swpm_wptpl_prop {#1} {#5}
  }
% \Review{work product}{method}{reviewer roles}{approver role}
\NewDocumentCommand \Review { m +m m m }
  {
    \seq_gput_right:Nn \g__swpm_reviews_seq { {#1} {#2} {#3} {#4} }
    \tl_if_blank:nF {#3} { \__swpm_prop_append:Nnn \g__swpm_wprev_prop {#1} {#3} }
    \tl_if_blank:nF {#4} { \prop_gput:Nnn \g__swpm_wpappr_prop {#1} {#4} }
  }
% \Informed{work product}{roles}
\NewDocumentCommand \Informed { m m }
  { \__swpm_prop_append:Nnn \g__swpm_wpinf_prop {#1} {#2} }

% =============================================================================
%  Input commands: configuration and change management  (configuration.tex)
% =============================================================================
% \ConfigItem{item}{location}{how it is controlled}
\NewDocumentCommand \ConfigItem { +m +m +m }
  { \__swpm_add:nn { configitems } { #1 & #2 & #3 \\ } }
% \Baseline{ID}{when / trigger}{content}{label}
\NewDocumentCommand \Baseline { m +m +m +m }
  { \__swpm_add:nn { baselines } { #1 & #2 & #3 & #4 \\ } }
% \Naming{object}{rule / pattern}{example}
\NewDocumentCommand \Naming { +m +m +m }
  { \__swpm_add:nn { naming } { #1 & #2 & \texttt{#3} \\ } }
% \Workflow{ID}{name}{states, in order}{tool / where}
\NewDocumentCommand \Workflow { m +m m +m }
  { \seq_gput_right:Nn \g__swpm_workflows_seq { {#1} {#2} {#3} {#4} } }

% =============================================================================
%  Input commands: quality assurance  (quality.tex)
% =============================================================================
% \QAActivity{activity}{when}{roles}{evidence}
\NewDocumentCommand \QAActivity { +m +m m +m }
  { \seq_gput_right:Nn \g__swpm_qa_seq { {#1} {#2} {#3} {#4} } }
% \Metric{metric}{target}{measured by / when}
\NewDocumentCommand \Metric { +m +m +m }
  { \__swpm_add:nn { metrics } { #1 & #2 & #3 \\ } }

% =============================================================================
%  Input commands: risks  (risks.tex)
% =============================================================================
% \Risk{ID}{risk}{probability}{impact}{mitigation}{owner role}
%   probability, impact: low | medium | high  (also l/m/h or 1/2/3)
\seq_new:N \g__swpm_risks_seq
\prop_new:N \g__swpm_risk_prop             % ID -> {risk}{P}{I}{mitigation}{owner}
\int_new:N \l__swpm_p_int
\int_new:N \l__swpm_i_int
\NewDocumentCommand \Risk { m +m m m +m m }
  {
    \prop_if_in:NnTF \g__swpm_risk_prop {#1}
      { \msg_warning:nnnn { swpm } { duplicate } { Risk } {#1} }
      { \seq_gput_right:Nn \g__swpm_risks_seq {#1} }
    \__swpm_level:nnN {#1} {#3} \l__swpm_p_int
    \__swpm_level:nnN {#1} {#4} \l__swpm_i_int
    \prop_gput:Nnx \g__swpm_risk_prop {#1}
      {
        { \exp_not:n {#2} } { \int_use:N \l__swpm_p_int } { \int_use:N \l__swpm_i_int }
        { \exp_not:n {#5} } { \exp_not:n {#6} }
      }
  }
% #3 := 1 / 2 / 3 for low / medium / high, 0 if not recognised (warning)
\cs_new_protected:Npn \__swpm_level:nnN #1#2#3
  {
    \str_set:Nx \l__swpm_s_str { \str_lowercase:n {#2} }
    \str_case:VnF \l__swpm_s_str
      {
        {low}    { \int_set:Nn #3 { 1 } }
        {l}      { \int_set:Nn #3 { 1 } }
        {1}      { \int_set:Nn #3 { 1 } }
        {medium} { \int_set:Nn #3 { 2 } }
        {m}      { \int_set:Nn #3 { 2 } }
        {2}      { \int_set:Nn #3 { 2 } }
        {high}   { \int_set:Nn #3 { 3 } }
        {h}      { \int_set:Nn #3 { 3 } }
        {3}      { \int_set:Nn #3 { 3 } }
      }
      {
        \msg_warning:nnnn { swpm } { bad-level } {#1} {#2}
        \int_set:Nn #3 { 0 }
      }
  }
\msg_new:nnn { swpm } { bad-level }
  { Risk~#1:~'#2'~is~not~'low',~'medium'~or~'high';~left~out~of~the~risk~matrix. }

% =============================================================================
%  Input commands: tools  (environment.tex)
% =============================================================================
% \Tool{name}{purpose}{version}{classification, e.g. TI1 TD3 TCL1}
\seq_new:N \g__swpm_tools_seq
\prop_new:N \g__swpm_tool_prop             % name -> {purpose}{version}{class}
\NewDocumentCommand \Tool { m +m m m }
  {
    \prop_if_in:NnTF \g__swpm_tool_prop {#1}
      { \msg_warning:nnnn { swpm } { duplicate } { Tool } {#1} }
      { \seq_gput_right:Nn \g__swpm_tools_seq {#1} }
    \prop_gput:Nnn \g__swpm_tool_prop {#1} { {#2} {#3} {#4} }
  }

% =============================================================================
%  Input commands: developer manual  (development.tex)
% =============================================================================
% \Rule{area}{rule}{enforced by: tools}
\NewDocumentCommand \Rule { m +m m }
  { \seq_gput_right:Nn \g__swpm_rules_seq { {#1} {#2} {#3} } }
% \CIStage{stage}{what it does / checks}{tools}{blocking: yes | no}
\NewDocumentCommand \CIStage { m +m m m }
  { \seq_gput_right:Nn \g__swpm_cistages_seq { {#1} {#2} {#3} {#4} } }
% \DoneCriterion{text}   -- Definition of Done
\NewDocumentCommand \DoneCriterion { +m }
  { \__swpm_add:nn { done } { \item #1 } }
% \begin{HowTo}{ID}{title}  \Goal{}  \Tools{tool, tool}  \Step{action}{command}  \end{HowTo}
\NewDocumentEnvironment { HowTo } { m m +b }
  { \seq_gput_right:Nn \g__swpm_howtos_seq { {#1} {#2} {#3} } }
  { }

% =============================================================================
%  Input commands: open point list  (opl.tex)
% =============================================================================
% \OpenPointExport{date YYYY-MM-DD}{source}   -- as-of date of the list
% \OpenPoint[top rank 1-5]{ID}{topic}{status}{responsible}{date}{comment}
%   status: open | in progress | closed; date: due date (open, in progress)
%   or closing date (closed)
\seq_new:N \g__swpm_ops_seq                % {rank}{rank note}{status}{raw}{ID}{topic}{resp}{date}{comment}
\prop_new:N \g__swpm_op_prop               % ID -> {} (duplicate check)
\str_new:N \l__swpm_op_str
\tl_new:N \l__swpm_op_note_tl
\int_new:N \l__swpm_op_rank_int
\NewDocumentCommand \OpenPointExport { m +m }
  {
    \prop_gput:Nnn \g__swpm_meta_prop { OPLDate } {#1}
    \prop_gput:Nnn \g__swpm_meta_prop { OPLSource } {#2}
  }
\NewDocumentCommand \OpenPoint { o m +m m m m +m }
  {
    \prop_if_in:NnTF \g__swpm_op_prop {#2}
      { \msg_warning:nnnn { swpm } { duplicate } { Open~point } {#2} }
      { \prop_gput:Nnn \g__swpm_op_prop {#2} { } }
    % status: o open, p in progress, c closed, x unknown
    \str_set:Nx \l__swpm_op_str { \str_lowercase:n {#4} }
    \str_remove_all:Nn \l__swpm_op_str { ~ }
    \str_remove_all:Nn \l__swpm_op_str { - }
    \str_case:VnF \l__swpm_op_str
      {
        {open}       { \str_set:Nn \l__swpm_op_str { o } }
        {inprogress} { \str_set:Nn \l__swpm_op_str { p } }
        {closed}     { \str_set:Nn \l__swpm_op_str { c } }
      }
      { \str_set:Nn \l__swpm_op_str { x } }
    % top rank: 1..5, else 0 and a red note
    \int_zero:N \l__swpm_op_rank_int
    \tl_clear:N \l__swpm_op_note_tl
    \IfValueT {#1}
      {
        \regex_match:nnTF { \A \s* [1-5] \s* \Z } {#1}
          { \int_set:Nn \l__swpm_op_rank_int {#1} }
          { \tl_set:Nn \l__swpm_op_note_tl { \__swpm_warn:n { #1~(not~1--5) } } }
      }
    \seq_gput_right:Nx \g__swpm_ops_seq
      {
        { \int_use:N \l__swpm_op_rank_int } { \exp_not:V \l__swpm_op_note_tl }
        { \l__swpm_op_str } \exp_not:n { {#4} {#2} {#3} {#5} {#6} {#7} }
      }
  }

% =============================================================================
%  Loading content
% =============================================================================
% \LoadManual{name}: loads the folder manuals/name (see \LoadContent).
%   Build-time override: if \SpecManual is defined before the class, e.g.
%     latexmk -pdf -jobname=foo -usepretex='\def\SpecManual{foo}' sw_project_manual.tex
%   it replaces name. A folder without metadata.tex gives a warning.
% \LoadContent{dir}: reads dir/<file>.tex for every content file (missing
%   files are skipped). Use in the preamble.
% Both set the search paths: manual first, then the shared folders at root
%   figures: dir/figures/, figures/  (\includegraphics, \InputFigure)
%   code:    dir/code/,    code/     (\InputCode)
%   data:    dir/data/,    data/
%   data and code are also added to LaTeX's \input@path. \ManualDir expands to dir.
\clist_const:Nn \c__swpm_files_clist
  { metadata, introduction, organization, lifecycle, workproducts,
    configuration, quality, risks, environment, development, opl }
\tl_new:N \g__swpm_dir_tl
\tl_new:N \l__swpm_found_tl
\cs_new:Npn \ManualDir { \g__swpm_dir_tl }
\cs_new_protected:Npn \__swpm_input:n #1
  { \file_if_exist_input:nF { \g__swpm_dir_tl / #1 .tex } { } }
\cs_new_protected:Npn \__swpm_set_paths:
  {
    \use:x { \exp_not:N \graphicspath { { \g__swpm_dir_tl / figures/ } { figures/ } } }
    \cs_if_exist:NF \input@path { \tl_gset:Nn \input@path { } }
    \tl_gput_left:Nx \input@path
      { { \g__swpm_dir_tl / data/ } { \g__swpm_dir_tl / code/ } { data/ } { code/ } }
  }
% \__swpm_find:nnTF {kind}{file}: manual folder first, then shared folder;
% the path found is in \l__swpm_found_tl. Names are turned into strings
% first: underscore makes _ active.
\tl_new:N \l__swpm_name_tl
\prg_new_protected_conditional:Npnn \__swpm_find:nn #1#2 { TF }
  {
    \tl_set:Nx \l__swpm_name_tl { \tl_to_str:n {#2} }
    \file_if_exist:nTF { \g__swpm_dir_tl / #1 / \l__swpm_name_tl }
      {
        \tl_set:Nx \l__swpm_found_tl { \g__swpm_dir_tl / #1 / \l__swpm_name_tl }
        \prg_return_true:
      }
      {
        \file_if_exist:nTF { #1 / \l__swpm_name_tl }
          { \tl_set:Nx \l__swpm_found_tl { #1 / \l__swpm_name_tl } \prg_return_true: }
          { \prg_return_false: }
      }
  }
\msg_new:nnn { swpm } { missing-file }
  { #1~`#2'~not~found~in~\g__swpm_dir_tl / #1/~nor~in~#1/. }
\msg_new:nnn { swpm } { missing-manual }
  { Manual~folder~`#1'~has~no~metadata.tex. }
\cs_new_protected:Npn \__swpm_missing:nn #1#2
  {
    \msg_warning:nnnn { swpm } { missing-file } {#1} {#2}
    \fbox { \textcolor{warn}{ missing~#1/#2 } }
  }
% \InputFigure[max width]{name}: figure code name.tex (a tikzpicture),
% shrunk to max width (default \linewidth), never enlarged.
\NewDocumentCommand \InputFigure { O{\linewidth} m }
  {
    \__swpm_find:nnTF { figures } { #2 .tex }
      { \begin{adjustbox}{max~width=#1} \input{\l__swpm_found_tl} \end{adjustbox} }
      { \__swpm_missing:nn { figures } { #2 .tex } }
  }
% \InputCode[fancyvrb options]{file}: a file from code/, verbatim.
\NewDocumentCommand \InputCode { O{} m }
  {
    \__swpm_find:nnTF { code } {#2}
      { \exp_args:NnV \__swpm_verbatim_input:nn {#1} \l__swpm_found_tl }
      { \__swpm_missing:nn { code } {#2} }
  }
\cs_new_protected:Npn \__swpm_verbatim_input:nn #1#2
  { \VerbatimInput [ fontsize = \small , #1 ] {#2} }
% Macro files: macros.tex at the template root (once), then dir/macros.tex,
% both optional, read before the content files; the folder's may \renewcommand.
\bool_new:N \g__swpm_root_macros_bool
\NewDocumentCommand \LoadContent { m }
  {
    \tl_gset:Nx \g__swpm_dir_tl { \tl_to_str:n {#1} }
    \typeout { swpm:~content~folder~`\g__swpm_dir_tl' }
    % root macros before the search paths: no data/ or code/ file of that name
    \bool_if:NF \g__swpm_root_macros_bool
      {
        \file_if_exist_input:n { ./macros.tex }
        \bool_gset_true:N \g__swpm_root_macros_bool
      }
    \__swpm_set_paths:
    \__swpm_input:n { macros }
    \clist_map_inline:Nn \c__swpm_files_clist
      { \tl_gset:Nn \g__swpm_chapter_tl {##1} \__swpm_input:n {##1} }
    \tl_gset:Nn \g__swpm_chapter_tl { inplace }
  }
\NewDocumentCommand \LoadManual { m }
  {
    \cs_if_exist:NTF \SpecManual
      { \tl_set:Nx \l_tmpa_tl { manuals / \tl_to_str:N \SpecManual } }
      { \tl_set:Nx \l_tmpa_tl { manuals / \tl_to_str:n {#1} } }
    \file_if_exist:nF { \l_tmpa_tl / metadata.tex }
      { \exp_args:NnnV \msg_warning:nnn { swpm } { missing-manual } \l_tmpa_tl }
    \exp_args:NV \LoadContent \l_tmpa_tl
  }

% =============================================================================
%  Page layout
% =============================================================================
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\textbf{\__swpm_meta:n{DocTitle}}\\\small \__swpm_meta:n{ProjectName}}
\fancyhead[R]{\small \__swpm_meta:n{DocID}\ \textbar\ v\__swpm_meta:n{DocVersion}\\\small \__swpm_meta:n{DocStatus}}
\fancyfoot[L]{\small \__swpm_meta:n{Company}}
\fancyfoot[R]{\small Page~\thepage\ of~\pageref*{LastPage}}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}

% =============================================================================
%  Diagrams
% =============================================================================
% ---- organisation chart: roles as a tree (\Role[reports to]) ---------------
\seq_new:N \l__swpm_level_seq
\seq_new:N \l__swpm_next_seq
\prop_new:N \l__swpm_drawn_prop
\int_new:N \l__swpm_level_int
\cs_new_protected:Npn \__swpm_role_box:nnn #1#2#3   % index in level, count, role
  {
    \tl_set:Nx \l__swpm_x_tl { \prop_item:Nn \g__swpm_roleidx_prop {#3} }
    \prop_put:Nnn \l__swpm_drawn_prop {#3} { }
    \prop_get:NnNF \g__swpm_rolemembers_prop {#3} \l__swpm_a_tl
      { \tl_set:Nn \l__swpm_a_tl { \__swpm_warn:n { no~member } } }
    \prop_get:NnN \g__swpm_role_prop {#3} \l__swpm_b_tl
    \node [ swpm/role ] (R\l__swpm_x_tl)
      at ( \fp_to_dim:n { 3.7cm * ( #1 - ( #2 + 1 ) / 2 ) } , \dim_eval:n { -2.5cm * \l__swpm_level_int } )
      {
        \textbf{ \l__swpm_b_tl } ~ {\scriptsize(#3)} \\[1pt]
        { \scriptsize \l__swpm_a_tl }
      } ;
  }
\cs_new_protected:Npn \__swpm_org_edge:n #1   % role
  {
    \prop_get:NnNT \g__swpm_roleparent_prop {#1} \l__swpm_a_tl
      {
        \bool_lazy_and:nnT
          { \prop_if_in_p:Nn \l__swpm_drawn_prop {#1} }
          { \prop_if_in_p:NV \l__swpm_drawn_prop \l__swpm_a_tl }
          {
            \tl_set:Nx \l__swpm_c_tl { \prop_item:Nn \g__swpm_roleidx_prop {#1} }
            \tl_set:Nx \l__swpm_d_tl { \prop_item:NV \g__swpm_roleidx_prop \l__swpm_a_tl }
            \draw [ swpm/edge ] (R\l__swpm_c_tl.north) -- ++(0, 0.4cm) -| (R\l__swpm_d_tl.south) ;
          }
      }
  }
\cs_generate_variant:Nn \prop_item:Nn { NV }
\cs_new_protected:Npn \__swpm_org_chart:
  {
    \prop_clear:N \l__swpm_drawn_prop
    \seq_clear:N \l__swpm_level_seq
    \seq_map_inline:Nn \g__swpm_roles_seq   % roots: no (known) parent
      {
        \prop_get:NnNTF \g__swpm_roleparent_prop {##1} \l__swpm_a_tl
          {
            \prop_if_in:NVF \g__swpm_role_prop \l__swpm_a_tl
              {
                \use:x
                  {
                    \exp_not:N \msg_warning:nnnn { swpm } { unknown-parent }
                      { \exp_not:n {##1} } { \tl_to_str:N \l__swpm_a_tl }
                  }
                \seq_put_right:Nn \l__swpm_level_seq {##1}
              }
          }
          { \seq_put_right:Nn \l__swpm_level_seq {##1} }
      }
    \int_zero:N \l__swpm_level_int
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \bool_until_do:nn
        { \seq_if_empty_p:N \l__swpm_level_seq || \int_compare_p:nNn \l__swpm_level_int > 7 }
        {
          \int_set:Nn \l_tmpa_int { \seq_count:N \l__swpm_level_seq }
          \seq_map_indexed_inline:Nn \l__swpm_level_seq
            { \__swpm_role_box:nnn {##1} { \l_tmpa_int } {##2} }
          \seq_clear:N \l__swpm_next_seq
          \seq_map_inline:Nn \l__swpm_level_seq
            {
              \seq_map_inline:Nn \g__swpm_roles_seq
                {
                  \prop_get:NnNT \g__swpm_roleparent_prop {####1} \l__swpm_a_tl
                    {
                      \bool_lazy_and:nnT
                        { \str_if_eq_p:Vn \l__swpm_a_tl {##1} }
                        { ! \prop_if_in_p:Nn \l__swpm_drawn_prop {####1} }
                        { \seq_put_right:Nn \l__swpm_next_seq {####1} }
                    }
                }
            }
          \seq_set_eq:NN \l__swpm_level_seq \l__swpm_next_seq
          \int_incr:N \l__swpm_level_int
        }
      \seq_map_inline:Nn \g__swpm_roles_seq { \__swpm_org_edge:n {##1} }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\msg_new:nnn { swpm } { unknown-parent }
  { \Role[#2]{#1}:~role~#2~is~not~declared;~#1~is~drawn~as~a~top~role. }

% ---- chain: boxes left to right (workflow states, CI stages) ---------------
% #1: seq of {title}{subtitle}
\cs_new_protected:Npn \__swpm_chain:N #1
  {
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \seq_map_indexed_inline:Nn #1 { \__swpm_chain_box:nnn {##1} ##2 }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__swpm_chain_box:nnn #1#2#3
  {
    \node [ swpm/state ] (C#1) at ( \dim_eval:n { 3.0cm * ( #1 - 1 ) } , 0 )
      { \textbf{#2} \tl_if_blank:nF {#3} { \\ {\scriptsize #3} } } ;
    \int_compare:nNnT {#1} > { 1 }
      {
        \tl_set:Nx \l__swpm_x_tl { \int_eval:n { #1 - 1 } }
        \draw [ swpm/flow ] (C\l__swpm_x_tl.east) -- (C#1.west) ;
      }
  }
\seq_new:N \l__swpm_chain_seq

% ---- timeline: milestones above, releases below ----------------------------
\seq_new:N \l__swpm_date_seq
\clist_const:Nn \c__swpm_cum_clist { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
\bool_new:N \l__swpm_dates_ok_bool
\int_new:N \l__swpm_day_int
\int_new:N \l__swpm_min_int
\int_new:N \l__swpm_max_int
\prop_new:N \l__swpm_day_prop             % M:<id> / R:<n> -> day number
% \l__swpm_day_int := day number of date #1 (YYYY-MM-DD), or the bool is cleared
\cs_new_protected:Npn \__swpm_day:n #1
  {
    \regex_extract_once:nnNTF { \A \s* (\d{4}) - (\d{1,2}) - (\d{1,2}) \s* \Z } {#1} \l__swpm_date_seq
      {
        \int_set:Nn \l__swpm_day_int
          {
            365 * \seq_item:Nn \l__swpm_date_seq { 2 }
            + \int_div_truncate:nn { \seq_item:Nn \l__swpm_date_seq { 2 } } { 4 }
            + \clist_item:Nn \c__swpm_cum_clist { \seq_item:Nn \l__swpm_date_seq { 3 } }
            + \seq_item:Nn \l__swpm_date_seq { 4 }
          }
      }
      { \bool_set_false:N \l__swpm_dates_ok_bool \int_zero:N \l__swpm_day_int }
  }
\cs_new_protected:Npn \__swpm_minmax:
  {
    \int_compare:nNnT \l__swpm_day_int < \l__swpm_min_int { \int_set_eq:NN \l__swpm_min_int \l__swpm_day_int }
    \int_compare:nNnT \l__swpm_day_int > \l__swpm_max_int { \int_set_eq:NN \l__swpm_max_int \l__swpm_day_int }
  }
% x of event #1 (key in \l__swpm_day_prop) / number #2 of #3 if dates are not usable
\cs_new:Npn \__swpm_tx:nnn #1#2#3
  {
    \bool_if:NTF \l__swpm_dates_ok_bool
      {
        \fp_to_dim:n
          {
            14cm * ( \prop_item:Nn \l__swpm_day_prop {#1} - \int_use:N \l__swpm_min_int )
            / max ( 1 , \int_use:N \l__swpm_max_int - \int_use:N \l__swpm_min_int )
          }
      }
      { \fp_to_dim:n { 14cm * ( #2 - 1 ) / max ( 1 , #3 - 1 ) } }
  }
\cs_new_protected:Npn \__swpm_timeline:
  {
    \bool_set_true:N \l__swpm_dates_ok_bool
    \prop_clear:N \l__swpm_day_prop
    \int_set:Nn \l__swpm_min_int { 100000000 }
    \int_set:Nn \l__swpm_max_int { -1 }
    \seq_map_inline:Nn \g__swpm_ms_seq
      {
        \prop_get:NnN \g__swpm_msdate_prop {##1} \l__swpm_a_tl
        \exp_args:NV \__swpm_day:n \l__swpm_a_tl
        \__swpm_minmax:
        \prop_put:Nnx \l__swpm_day_prop { M:##1 } { \int_use:N \l__swpm_day_int }
      }
    \seq_map_indexed_inline:Nn \g__swpm_releases_seq
      {
        \__swpm_day_of_release:nnnnn {##1} ##2
        \__swpm_minmax:
        \prop_put:Nnx \l__swpm_day_prop { R:##1 } { \int_use:N \l__swpm_day_int }
      }
    \begin{center}
    \begin{adjustbox}{max~width=\linewidth}
    \begin{tikzpicture}
      \draw [ swpm/time ] ( -0.6cm , 0 ) -- ( 14.8cm , 0 ) ;
      \int_set:Nn \l_tmpa_int { \seq_count:N \g__swpm_ms_seq }
      \seq_map_indexed_inline:Nn \g__swpm_ms_seq
        {
          \tl_set:Nx \l__swpm_x_tl { \__swpm_tx:nnn { M:##2 } {##1} { \l_tmpa_int } }
          \prop_get:NnN \g__swpm_msdate_prop {##2} \l__swpm_a_tl
          \node [ swpm/ms ] at ( \l__swpm_x_tl , 0 ) { } ;
          \draw [ swpm/tick ] ( \l__swpm_x_tl , 0.15cm )
            -- ( \l__swpm_x_tl , \int_if_odd:nTF {##1} { 0.45cm } { 1.25cm } ) ;
          \node [ swpm/tlabel , anchor = south ]
            at ( \l__swpm_x_tl , \int_if_odd:nTF {##1} { 0.45cm } { 1.25cm } )
            { \textbf{##2} \\ \l__swpm_a_tl } ;
        }
      \int_set:Nn \l_tmpb_int { \seq_count:N \g__swpm_releases_seq }
      \seq_map_indexed_inline:Nn \g__swpm_releases_seq
        { \__swpm_release_mark:nnnnn {##1} ##2 }
    \end{tikzpicture}
    \end{adjustbox}
    \end{center}
  }
\cs_new_protected:Npn \__swpm_day_of_release:nnnnn #1#2#3#4#5 { \__swpm_day:n {#3} }
\cs_new_protected:Npn \__swpm_release_mark:nnnnn #1#2#3#4#5   % n version date content ms
  {
    \tl_set:Nx \l__swpm_x_tl { \__swpm_tx:nnn { R:#1 } {#1} { \l_tmpb_int } }
    \node [ swpm/rel ] at ( \l__swpm_x_tl , 0 ) { } ;
    \draw [ swpm/tick ] ( \l__swpm_x_tl , -0.15cm )
      -- ( \l__swpm_x_tl , \int_if_odd:nTF {#1} { -0.45cm } { -1.25cm } ) ;
    \node [ swpm/tlabel , anchor = north ]
      at ( \l__swpm_x_tl , \int_if_odd:nTF {#1} { -0.45cm } { -1.25cm } )
      { \textbf{#2} \\ #3 } ;
  }

% ---- risk matrix: probability x impact, risk IDs in the cells --------------
\prop_new:N \l__swpm_cell_prop            % <p><i> -> risk IDs
\cs_new_protected:Npn \__swpm_risk_cell:nn #1#2   % p i
  {
    \int_set:Nn \l_tmpa_int { #1 * #2 }
    \tl_set:Nx \l__swpm_x_tl
      {
        \int_compare:nNnTF \l_tmpa_int < 3 { risklow }
          { \int_compare:nNnTF \l_tmpa_int < 6 { riskmed } { riskhigh } }
      }
    \prop_get:NnNF \l__swpm_cell_prop { #1#2 } \l__swpm_a_tl { \tl_clear:N \l__swpm_a_tl }
    \node [ swpm/cell , fill = \l__swpm_x_tl ]
      at ( \dim_eval:n { 3.2cm * #2 } , \dim_eval:n { 1.5cm * #1 } ) { \l__swpm_a_tl } ;
  }
\cs_new_protected:Npn \__swpm_risk_matrix:
  {
    \prop_clear:N \l__swpm_cell_prop
    \seq_map_inline:Nn \g__swpm_risks_seq
      {
        \prop_get:NnN \g__swpm_risk_prop {##1} \l__swpm_a_tl
        \tl_set:Nx \l__swpm_b_tl { \tl_item:Nn \l__swpm_a_tl { 2 } \tl_item:Nn \l__swpm_a_tl { 3 } }
        \bool_lazy_or:nnF
          { \int_compare_p:nNn { \tl_item:Nn \l__swpm_a_tl { 2 } } = 0 }
          { \int_compare_p:nNn { \tl_item:Nn \l__swpm_a_tl { 3 } } = 0 }
          { \__swpm_cell_add:Vn \l__swpm_b_tl {##1} }
      }
    \begin{center}
    \begin{tikzpicture}
      \int_step_inline:nn { 3 }
        { \int_step_inline:nn { 3 } { \__swpm_risk_cell:nn {##1} {####1} } }
      \clist_map_inline:nn { 1/low, 2/medium, 3/high } { \__swpm_axis:w ##1 \q_stop }
      \node [ font = \small\bfseries , anchor = base ] at ( 6.4cm , 0.0cm ) { Impact } ;
      \node [ font = \small\bfseries , rotate = 90 ] at ( -0.2cm , 3.0cm ) { Probability } ;
    \end{tikzpicture}
    \end{center}
  }
\cs_new_protected:Npn \__swpm_axis:w #1 / #2 \q_stop
  {
    \node [ font = \small , anchor = base ] at ( \dim_eval:n { 3.2cm * #1 } , 0.4cm ) {#2} ;
    \node [ font = \small , anchor = east ] at ( 1.5cm , \dim_eval:n { 1.5cm * #1 } ) {#2} ;
  }
\cs_new:Npn \__swpm_level_name:n #1
  { \int_case:nnF {#1} { {1} {low} {2} {medium} {3} {high} } { \__swpm_warn:n {?} } }
% risk matrix cell #1 += risk ID #2
\cs_new_protected:Npn \__swpm_cell_add:nn #1#2
  {
    \prop_get:NnNTF \l__swpm_cell_prop {#1} \l__swpm_tmp_tl
      { \tl_put_right:Nn \l__swpm_tmp_tl { ,~ #2 } }
      { \tl_set:Nn \l__swpm_tmp_tl {#2} }
    \prop_put:NnV \l__swpm_cell_prop {#1} \l__swpm_tmp_tl
  }
\cs_generate_variant:Nn \__swpm_cell_add:nn { V }

% =============================================================================
%  Chapters -- placed in the main file, in any order, each optional
% =============================================================================
\NewDocumentCommand \SpecTitlePage {}
  {
    \hypersetup{pageanchor=false}   % title page: no duplicate page.1 anchor
    \begin{titlepage}
      \centering
      \vspace*{3cm}
      {\Large \__swpm_meta:n{ProjectName}\par}
      \vspace{1cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{0.4cm}
      {\Huge\bfseries \__swpm_meta:n{DocTitle}\par}
      \vspace{0.3cm}
      {\Large Component:~\TheComponent\par}
      \vspace{0.4cm}
      {\color{accent}\rule{\linewidth}{1pt}\par}
      \vspace{2cm}
      \begin{tabular}{@{}ll@{}}
        \toprule
        Document~ID      & \__swpm_meta:n{DocID} \\
        Version          & \__swpm_meta:n{DocVersion} \\
        Status           & \__swpm_meta:n{DocStatus} \\
        Date             & \__swpm_meta:n{DocDate} \\
        Project~ID       & \__swpm_meta:n{ProjectID} \\
        Customer         & \__swpm_meta:n{Customer} \\
        Integrity~level  & \__swpm_meta:n{IntegrityLevel} \\
        Author           & \__swpm_meta:n{Author} \\
        \bottomrule
      \end{tabular}
      \vfill
      {\small \__swpm_meta:n{Company}}
    \end{titlepage}
    \hypersetup{pageanchor=true}
  }

\NewDocumentCommand \SpecDocumentControl {}
  {
    \section*{Document~Control}
    \subsection*{Revision~History}
    \__swpm_list_table:nnnn { @{}l l L{3cm} Y@{} } {4}
      { \textbf{Version} & \textbf{Date} & \textbf{Author} & \textbf{Change} } { revisions }
    \subsection*{Review~and~Approval}
    \begin{tabularx}{\linewidth}{@{}l L{4cm} X l@{}}
      \toprule
      \textbf{Role} & \textbf{Name} & \textbf{Signature} & \textbf{Date} \\ \midrule
      Author   & \__swpm_meta:n{Author}   & & \\
      Reviewer & \__swpm_meta:n{Reviewer} & & \\
      Approver & \__swpm_meta:n{Approver} & & \\
      \bottomrule
    \end{tabularx}
    \__swpm_free:n { metadata }
  }

\NewDocumentCommand \SpecContents {}
  { \tableofcontents \clearpage }

% ---- 1 Introduction ----------------------------------------------------------
\cs_new_protected:Npn \__swpm_deliverable_row:nnn #1#2#3
  {
    \__swpm_check_opt:nNnN {#3} \g__swpm_ms_prop { milestone } \l__swpm_a_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:N \\ }
  }
\NewDocumentCommand \SpecIntroduction {}
  {
    \section{Introduction}
    \subsection{Purpose}
    \__swpm_text:nn { Purpose }
      {
        This~manual~defines~how~the~project~\TheProject{}~develops~the~software~
        component~\TheComponent{}:~organisation~and~roles,~the~process~and~its~
        tailoring,~milestones~and~releases,~work~products~and~reviews,~configuration~
        and~change~management,~quality~assurance,~risks~and~tools.~Its~developer~
        manual~says~how~the~team~works~day~to~day.~It~is~binding~for~every~member~
        of~the~project.
      }
    \subsection{Scope}
    \__swpm_text:nn { Scope } { \ph{Scope} }
    \subsection{Project~Identification}
    \begin{tabularx}{\linewidth}{@{}L{4.4cm} Y@{}}
      \toprule
      Project            & \__swpm_meta:n{ProjectName} \\
      Project~ID         & \__swpm_meta:n{ProjectID} \\
      Customer           & \__swpm_meta:n{Customer} \\
      Component          & \TheComponent \\
      Integrity~level    & \__swpm_meta:n{IntegrityLevel} \\
      Duration           & \__swpm_meta:n{ProjectStart}~--~\__swpm_meta:n{ProjectEnd} \\
      Repository         & \__swpm_meta:n{Repository} \\
      \bottomrule
    \end{tabularx}
    \subsection{Project~Objectives}
    \__swpm_itemize:n { objectives }
    \Needspace{6\baselineskip}
    \subsection{Deliverables}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_deliverables_seq { \__swpm_deliverable_row:nnn ##1 }
    \__swpm_table:nnnN { @{}Y L{4cm} L{2.6cm}@{} } {3}
      { \textbf{Deliverable} & \textbf{Recipient} & \textbf{Milestone} } \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsection{References}
    \__swpm_list_table:nnnn { @{}l Y l l@{} } {4}
      { \textbf{ID} & \textbf{Document} & \textbf{Type} & \textbf{Version} } { references }
    \Needspace{6\baselineskip}
    \subsection{Terms~and~Abbreviations}
    \__swpm_list_table:nnnn { @{}l Y@{} } {2}
      { \textbf{Term} & \textbf{Definition} } { terms }
    \__swpm_free:n { introduction }
  }

% ---- 2 Organization ----------------------------------------------------------
\cs_new_protected:Npn \__swpm_role_row:n #1
  {
    \prop_get:NnN \g__swpm_role_prop {#1} \l__swpm_a_tl
    \prop_get:NnN \g__swpm_roleresp_prop {#1} \l__swpm_b_tl
    \prop_get:NnNF \g__swpm_rolemembers_prop {#1} \l__swpm_c_tl
      { \tl_set:Nn \l__swpm_c_tl { \__swpm_warn:n { no~member~(add~a~\string\Member) } } }
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #1 & } \exp_not:V \l__swpm_a_tl & \exp_not:V \l__swpm_b_tl
        & \exp_not:V \l__swpm_c_tl \exp_not:N \\
      }
  }
\cs_new_protected:Npn \__swpm_member_row:nnn #1#2#3
  {
    \__swpm_check_req:nNnN {#2} \g__swpm_role_prop { role } \l__swpm_a_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & } \exp_not:V \l__swpm_a_tl \exp_not:n { & #3 \\ } }
  }
\cs_new_protected:Npn \__swpm_stakeholder_row:nnn #1#2#3
  {
    \__swpm_check_opt:nNnN {#3} \g__swpm_role_prop { role } \l__swpm_a_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:N \\ }
  }
\cs_new_protected:Npn \__swpm_meeting_row:nnnn #1#2#3#4
  {
    \__swpm_check_req:nNnN {#3} \g__swpm_role_prop { role } \l__swpm_a_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:n { & #4 \\ } }
  }
\NewDocumentCommand \SpecOrganization {}
  {
    \section{Organization}
    \subsection{Roles}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_roles_seq { \__swpm_role_row:n {##1} }
    \__swpm_table:nnnN { @{}l L{3.2cm} Y L{3.2cm}@{} } {4}
      { \textbf{ID} & \textbf{Role} & \textbf{Responsibility} & \textbf{Members} } \l__swpm_rows_tl
    \seq_if_empty:NF \g__swpm_roles_seq
      {
        \Needspace{10\baselineskip}
        Organisation~chart~(lines:~reports~to):
        \__swpm_org_chart:
      }
    \Needspace{6\baselineskip}
    \subsection{Team}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_members_seq { \__swpm_member_row:nnn ##1 }
    \__swpm_table:nnnN { @{}L{3.6cm} L{3.2cm} Y@{} } {3}
      { \textbf{Name} & \textbf{Roles} & \textbf{Organisation~/~Contact} } \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsection{Stakeholders~and~Interfaces}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_stakeholders_seq { \__swpm_stakeholder_row:nnn ##1 }
    \__swpm_table:nnnN { @{}L{3.6cm} Y L{2.6cm}@{} } {3}
      { \textbf{Stakeholder} & \textbf{Interest~/~Interface} & \textbf{Contact~role} } \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsection{Meetings}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_meetings_seq { \__swpm_meeting_row:nnnn ##1 }
    \__swpm_table:nnnN { @{}L{3.2cm} L{2.4cm} L{2.8cm} Y@{} } {4}
      { \textbf{Meeting} & \textbf{Cadence} & \textbf{Participants} & \textbf{Purpose~/~Output} } \l__swpm_rows_tl
    \subsection{Reporting~and~Communication}
    \__swpm_text:nn { Communication } { \ph{Communication} }
    \__swpm_free:n { organization }
  }

% ---- 3 Process and Lifecycle ---------------------------------------------------
\prop_new:N \l__swpm_procwp_prop          % process -> work products
\cs_new_protected:Npn \__swpm_build_procwp:
  {
    \prop_clear:N \l__swpm_procwp_prop
    \seq_map_inline:Nn \g__swpm_wps_seq
      {
        \prop_get:NnN \g__swpm_wpproc_prop {##1} \l__swpm_a_tl
        \clist_set:NV \l__swpm_x_clist \l__swpm_a_tl
        \clist_map_inline:Nn \l__swpm_x_clist
          {
            \prop_get:NnNTF \l__swpm_procwp_prop {####1} \l__swpm_tmp_tl
              { \tl_put_right:Nn \l__swpm_tmp_tl { ,~ ##1 } }
              { \tl_set:Nn \l__swpm_tmp_tl {##1} }
            \prop_put:NnV \l__swpm_procwp_prop {####1} \l__swpm_tmp_tl
          }
      }
  }
\cs_new_protected:Npn \__swpm_proc_row:n #1
  {
    \prop_get:NnN \g__swpm_proc_prop {#1} \l__swpm_a_tl
    \prop_get:NnN \g__swpm_procrat_prop {#1} \l__swpm_b_tl
    \prop_get:NnN \g__swpm_procscope_prop {#1} \l__swpm_x_tl
    \prop_get:NnNF \l__swpm_procwp_prop {#1} \l__swpm_c_tl { \tl_clear:N \l__swpm_c_tl }
    \str_case:VnF \l__swpm_x_tl
      {
        {Y} { \tl_set:Nn \l__swpm_d_tl { yes } }
        {T} { \tl_set:Nn \l__swpm_d_tl { tailored } }
        {N} { \tl_set:Nn \l__swpm_d_tl { no } }
      }
      { \tl_set:Nn \l__swpm_d_tl { \__swpm_warn:n {?} } }
    \tl_if_empty:NT \l__swpm_c_tl
      {
        \str_if_eq:VnTF \l__swpm_x_tl { N }
          { \tl_set:Nn \l__swpm_c_tl { -- } }
          { \tl_set:Nn \l__swpm_c_tl { \__swpm_warn:n { none~(add~a~\string\WorkProduct) } } }
      }
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #1 & } \exp_not:V \l__swpm_a_tl & \exp_not:V \l__swpm_d_tl
        & \exp_not:V \l__swpm_b_tl & \exp_not:V \l__swpm_c_tl \exp_not:N \\
      }
  }
% #1 := #1, in red if it is not a date YYYY-MM-DD (the timeline needs it)
\cs_new_protected:Npn \__swpm_check_date:N #1
  {
    \regex_match:nVF { \A \s* \d{4} - \d{1,2} - \d{1,2} \s* \Z } #1
      { \tl_set:Nx #1 { \exp_not:N \__swpm_warn:n { \exp_not:V #1 ~ (not~YYYY-MM-DD) } } }
  }
\cs_generate_variant:Nn \regex_match:nnF { nV }
\cs_new_protected:Npn \__swpm_ms_row:n #1
  {
    \prop_get:NnN \g__swpm_ms_prop {#1} \l__swpm_a_tl
    \prop_get:NnN \g__swpm_msdate_prop {#1} \l__swpm_b_tl
    \__swpm_check_date:N \l__swpm_b_tl
    \prop_get:NnN \g__swpm_mscrit_prop {#1} \l__swpm_c_tl
    \__swpm_check_opt:VNnN \l__swpm_c_tl \g__swpm_wp_prop { work~product } \l__swpm_d_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #1 & } \exp_not:V \l__swpm_b_tl & \exp_not:V \l__swpm_a_tl
        & \exp_not:V \l__swpm_d_tl \exp_not:N \\
      }
  }
\cs_generate_variant:Nn \__swpm_check_opt:nNnN { VNnN }
\cs_new_protected:Npn \__swpm_release_row:nnnn #1#2#3#4
  {
    \__swpm_check_opt:nNnN {#4} \g__swpm_ms_prop { milestone } \l__swpm_a_tl
    \tl_set:Nn \l__swpm_b_tl {#2}
    \__swpm_check_date:N \l__swpm_b_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #1 & } \exp_not:V \l__swpm_b_tl \exp_not:n { & #3 & }
        \exp_not:V \l__swpm_a_tl \exp_not:N \\
      }
  }
\NewDocumentCommand \SpecLifecycle {}
  {
    \section{Process~and~Lifecycle}
    \subsection{Process~Reference}
    \__swpm_text:nn { ProcessReference } { \ph{ProcessReference} }
    \Needspace{8\baselineskip}
    \subsection{Process~Tailoring}
    Processes~of~the~reference~model,~whether~the~project~applies~them,~and~the~
    work~products~that~implement~them~(chapter~\ref{swpm:wp}):
    \__swpm_build_procwp:
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_procs_seq { \__swpm_proc_row:n {##1} }
    \__swpm_table:nnnN { @{}l L{3.6cm} l Y L{2.6cm}@{} } {5}
      { \textbf{ID} & \textbf{Process} & \textbf{Applied} & \textbf{Rationale} & \textbf{Work~products} }
      \l__swpm_rows_tl
    \Needspace{12\baselineskip}
    \subsection{Milestones~and~Releases}
    \bool_lazy_and:nnF
      { \seq_if_empty_p:N \g__swpm_ms_seq }
      { \seq_if_empty_p:N \g__swpm_releases_seq }
      {
        Timeline:~milestones~above~the~line,~software~releases~below.
        \__swpm_timeline:
      }
    \Needspace{6\baselineskip}
    \subsubsection{Milestones}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_ms_seq { \__swpm_ms_row:n {##1} }
    \__swpm_table:nnnN { @{}l l Y L{4.6cm}@{} } {4}
      { \textbf{ID} & \textbf{Date} & \textbf{Milestone} & \textbf{Exit~criteria:~work~products} }
      \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsubsection{Releases}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_releases_seq { \__swpm_release_row:nnnn ##1 }
    \__swpm_table:nnnN { @{}l l Y L{2.4cm}@{} } {4}
      { \textbf{Version} & \textbf{Date} & \textbf{Content} & \textbf{Milestone} } \l__swpm_rows_tl
    \__swpm_free:n { lifecycle }
  }

% ---- 4 Work Products -----------------------------------------------------------
\cs_new_protected:Npn \__swpm_wp_row:n #1
  {
    \prop_get:NnN \g__swpm_wp_prop {#1} \l__swpm_a_tl
    \prop_get:NnN \g__swpm_wpproc_prop {#1} \l__swpm_tmp_tl
    \__swpm_check_opt:VNnN \l__swpm_tmp_tl \g__swpm_proc_prop { process } \l__swpm_b_tl
    \prop_get:NnN \g__swpm_wpresp_prop {#1} \l__swpm_tmp_tl
    \__swpm_check_req:VNnN \l__swpm_tmp_tl \g__swpm_role_prop { role } \l__swpm_c_tl
    \__swpm_no_member:VN \l__swpm_tmp_tl \l__swpm_c_tl
    \prop_get:NnN \g__swpm_wptpl_prop {#1} \l__swpm_d_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #1 & } \exp_not:V \l__swpm_a_tl & \exp_not:V \l__swpm_b_tl
        & \exp_not:V \l__swpm_c_tl & \exp_not:V \l__swpm_d_tl \exp_not:N \\
      }
  }
\cs_generate_variant:Nn \__swpm_check_req:nNnN { VNnN }
% append a red note to #2 if a (known) role of clist #1 has no member
\cs_new_protected:Npn \__swpm_no_member:nN #1#2
  {
    \clist_set:Nn \l__swpm_x_clist {#1}
    \clist_map_inline:Nn \l__swpm_x_clist
      {
        \bool_lazy_and:nnT
          { \prop_if_in_p:Nn \g__swpm_role_prop {##1} }
          { ! \prop_if_in_p:Nn \g__swpm_rolemembers_prop {##1} }
          { \tl_put_right:Nn #2 { \__swpm_warn:n { ~(##1~has~no~member) } } }
      }
  }
\cs_generate_variant:Nn \__swpm_no_member:nN { VN }
\cs_new_protected:Npn \__swpm_review_row:nnnn #1#2#3#4
  {
    \__swpm_check:nNnN {#1} \g__swpm_wp_prop { work~product } \l__swpm_a_tl
    \__swpm_check_req:nNnN {#3} \g__swpm_role_prop { role } \l__swpm_b_tl
    \__swpm_check_opt:nNnN {#4} \g__swpm_role_prop { role } \l__swpm_c_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:V \l__swpm_a_tl \exp_not:n { & #2 & } \exp_not:V \l__swpm_b_tl
        & \exp_not:V \l__swpm_c_tl \exp_not:N \\
      }
  }
% RACI letters of work product #1 for role #2
\cs_new_protected:Npn \__swpm_raci_add:n #1
  {
    \tl_if_empty:NF \l__swpm_x_tl { \tl_put_right:Nn \l__swpm_x_tl { / } }
    \tl_put_right:Nn \l__swpm_x_tl {#1}
  }
\cs_new_protected:Npn \__swpm_raci_if:NnnT #1#2#3#4   % prop, wp, role
  {
    \prop_get:NnNT #1 {#2} \l__swpm_tmp_tl
      {
        \clist_set:NV \l__swpm_x_clist \l__swpm_tmp_tl
        \clist_if_in:NnT \l__swpm_x_clist {#3} {#4}
      }
  }
\cs_new_protected:Npn \__swpm_raci_cell:nn #1#2
  {
    \tl_clear:N \l__swpm_x_tl
    \__swpm_raci_if:NnnT \g__swpm_wpresp_prop {#1} {#2} { \__swpm_raci_add:n {R} }
    \__swpm_raci_if:NnnT \g__swpm_wpappr_prop {#1} {#2} { \__swpm_raci_add:n {A} }
    \__swpm_raci_if:NnnT \g__swpm_wprev_prop  {#1} {#2} { \__swpm_raci_add:n {C} }
    \__swpm_raci_if:NnnT \g__swpm_wpinf_prop  {#1} {#2} { \__swpm_raci_add:n {I} }
    \tl_put_right:Nx \l__swpm_rows_tl { & \exp_not:V \l__swpm_x_tl }
  }
\cs_new_protected:Npn \__swpm_raci:
  {
    \tl_set:Nx \l__swpm_spec_tl
      { @{} l Y \prg_replicate:nn { \seq_count:N \g__swpm_roles_seq } { c } @{} }
    \tl_set:Nn \l__swpm_head_tl { \textbf{ID} & \textbf{Work~product} }
    \seq_map_inline:Nn \g__swpm_roles_seq
      { \tl_put_right:Nn \l__swpm_head_tl { & \textbf{##1} } }
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_wps_seq
      {
        \prop_get:NnN \g__swpm_wp_prop {##1} \l__swpm_a_tl
        \tl_put_right:Nx \l__swpm_rows_tl { \exp_not:n { ##1 & } \exp_not:V \l__swpm_a_tl }
        \seq_map_inline:Nn \g__swpm_roles_seq { \__swpm_raci_cell:nn {##1} {####1} }
        \tl_put_right:Nn \l__swpm_rows_tl { \\ }
      }
    \use:x
      {
        \exp_not:N \__swpm_table:nnnN
          { \exp_not:V \l__swpm_spec_tl }
          { \int_eval:n { 2 + \seq_count:N \g__swpm_roles_seq } }
          { \exp_not:V \l__swpm_head_tl }
          \exp_not:N \l__swpm_rows_tl
      }
  }
\NewDocumentCommand \SpecWorkProducts {}
  {
    \section{Work~Products}\label{swpm:wp}
    \subsection{Work~Product~List}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_wps_seq { \__swpm_wp_row:n {##1} }
    \__swpm_table:nnnN { @{}l L{3.8cm} L{1.8cm} L{2.4cm} Y@{} } {5}
      { \textbf{ID} & \textbf{Work~product} & \textbf{Process} & \textbf{Responsible} & \textbf{Template~/~Location} }
      \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsection{Reviews}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_reviews_seq { \__swpm_review_row:nnnn ##1 }
    \__swpm_table:nnnN { @{}l Y L{3cm} L{2cm}@{} } {4}
      { \textbf{Work~product} & \textbf{Method} & \textbf{Reviewers} & \textbf{Approver} } \l__swpm_rows_tl
    \Needspace{8\baselineskip}
    \subsection{Responsibility~Matrix}
    R~=~responsible~(\string\WorkProduct),~A~=~approves,~C~=~consulted~
    (reviewers,~\string\Review),~I~=~informed~(\string\Informed).
    \seq_if_empty:NTF \g__swpm_roles_seq { \par \ph{no~roles} } { \__swpm_raci: }
    \__swpm_free:n { workproducts }
  }

% ---- 5 Configuration and Change Management -------------------------------------
\cs_new_protected:Npn \__swpm_workflow:nnnn #1#2#3#4
  {
    \Needspace{8\baselineskip}
    \subsubsection{#1:~#2}
    \seq_clear:N \l__swpm_chain_seq
    \clist_set:Nn \l__swpm_x_clist {#3}
    \clist_map_inline:Nn \l__swpm_x_clist
      { \seq_put_right:Nn \l__swpm_chain_seq { {##1} { } } }
    \tl_if_blank:nF {#4} { Tool~/~where:~#4 }
    \__swpm_chain:N \l__swpm_chain_seq
  }
\NewDocumentCommand \SpecConfiguration {}
  {
    \section{Configuration~and~Change~Management}
    \subsection{Configuration~Items}
    \__swpm_list_table:nnnn { @{}L{4cm} Y L{4.4cm}@{} } {3}
      { \textbf{Item} & \textbf{Location} & \textbf{Controlled~by} } { configitems }
    \subsection{Branching~Model}
    \__swpm_text:nn { BranchingModel } { \ph{BranchingModel} }
    \Needspace{6\baselineskip}
    \subsection{Baselines}
    \__swpm_list_table:nnnn { @{}l L{3.6cm} Y L{3.4cm}@{} } {4}
      { \textbf{ID} & \textbf{When} & \textbf{Content} & \textbf{Label} } { baselines }
    \Needspace{6\baselineskip}
    \subsection{Naming~Conventions}
    \__swpm_list_table:nnnn { @{}L{3.4cm} Y L{4.4cm}@{} } {3}
      { \textbf{Object} & \textbf{Rule} & \textbf{Example} } { naming }
    \subsection{Change~and~Problem~Handling}
    \seq_if_empty:NTF \g__swpm_workflows_seq { \ph{none} }
      { \seq_map_inline:Nn \g__swpm_workflows_seq { \__swpm_workflow:nnnn ##1 } }
    \subsection{Release~Procedure}
    \__swpm_text:nn { ReleaseProcedure } { \ph{ReleaseProcedure} }
    \__swpm_free:n { configuration }
  }

% ---- 6 Quality Assurance -------------------------------------------------------
\cs_new_protected:Npn \__swpm_qa_row:nnnn #1#2#3#4
  {
    \__swpm_check_req:nNnN {#3} \g__swpm_role_prop { role } \l__swpm_a_tl
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:n { & #4 \\ } }
  }
\NewDocumentCommand \SpecQuality {}
  {
    \section{Quality~Assurance}
    \subsection{Quality~Assurance~Activities}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_qa_seq { \__swpm_qa_row:nnnn ##1 }
    \__swpm_table:nnnN { @{}Y L{3cm} L{2cm} L{4cm}@{} } {4}
      { \textbf{Activity} & \textbf{When} & \textbf{Roles} & \textbf{Evidence} } \l__swpm_rows_tl
    \Needspace{6\baselineskip}
    \subsection{Metrics}
    \__swpm_list_table:nnnn { @{}L{4.4cm} L{3.4cm} Y@{} } {3}
      { \textbf{Metric} & \textbf{Target} & \textbf{Measured~by~/~when} } { metrics }
    \subsection{Escalation}
    \__swpm_text:nn { Escalation } { \ph{Escalation} }
    \__swpm_free:n { quality }
  }

% ---- 7 Risk Management ---------------------------------------------------------
\cs_new_protected:Npn \__swpm_risk_row:n #1
  {
    \prop_get:NnN \g__swpm_risk_prop {#1} \l__swpm_tmp_tl
    \exp_last_unbraced:NV \__swpm_risk_row:nnnnnn \l__swpm_tmp_tl {#1}
  }
\cs_new_protected:Npn \__swpm_risk_row:nnnnnn #1#2#3#4#5#6   % risk P I mitigation owner ID
  {
    \__swpm_check_req:nNnN {#5} \g__swpm_role_prop { owner } \l__swpm_a_tl
    \tl_if_blank:nTF {#4}
      { \tl_set:Nn \l__swpm_b_tl { \__swpm_warn:n { mitigation~missing } } }
      { \tl_set:Nn \l__swpm_b_tl {#4} }
    \tl_put_right:Nx \l__swpm_rows_tl
      {
        \exp_not:n { #6 & #1 & } \__swpm_level_name:n {#2} & \__swpm_level_name:n {#3}
        & \exp_not:V \l__swpm_b_tl & \exp_not:V \l__swpm_a_tl \exp_not:N \\
      }
  }
\NewDocumentCommand \SpecRisks {}
  {
    \section{Risk~Management}
    \seq_if_empty:NF \g__swpm_risks_seq
      {
        Risk~matrix~(green:~accept~and~monitor,~yellow:~mitigate,~red:~mitigate~and~
        report~in~every~steering~meeting):
        \__swpm_risk_matrix:
      }
    \subsection{Risk~Register}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_risks_seq { \__swpm_risk_row:n {##1} }
    \__swpm_table:nnnN { @{}l Y l l L{4.2cm} l@{} } {6}
      { \textbf{ID} & \textbf{Risk} & \textbf{P} & \textbf{I} & \textbf{Mitigation} & \textbf{Owner} }
      \l__swpm_rows_tl
    \__swpm_free:n { risks }
  }

% ---- 8 Tools and Environment ---------------------------------------------------
\bool_new:N \l__swpm_safety_bool
\cs_new_protected:Npn \__swpm_set_safety:
  {
    \prop_get:NnNF \g__swpm_meta_prop { IntegrityLevel } \l__swpm_tmp_tl
      { \tl_clear:N \l__swpm_tmp_tl }
    \tl_if_in:NnTF \l__swpm_tmp_tl { ASIL }
      { \bool_set_true:N \l__swpm_safety_bool }
      { \bool_set_false:N \l__swpm_safety_bool }
  }
\cs_new_protected:Npn \__swpm_tool_row:n #1
  {
    \prop_get:NnN \g__swpm_tool_prop {#1} \l__swpm_tmp_tl
    \exp_last_unbraced:NV \__swpm_tool_row:nnnn \l__swpm_tmp_tl {#1}
  }
\cs_new_protected:Npn \__swpm_tool_row:nnnn #1#2#3#4   % purpose version class name
  {
    \tl_if_blank:nTF {#3}
      {
        \bool_if:NTF \l__swpm_safety_bool
          { \tl_set:Nn \l__swpm_a_tl { \__swpm_warn:n { classification~missing } } }
          { \tl_set:Nn \l__swpm_a_tl { -- } }
      }
      { \tl_set:Nn \l__swpm_a_tl {#3} }
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #4 & #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:N \\ }
  }
\NewDocumentCommand \SpecEnvironment {}
  {
    \section{Tools~and~Environment}\label{swpm:tools}
    \__swpm_set_safety:
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_tools_seq { \__swpm_tool_row:n {##1} }
    \__swpm_table:nnnN { @{}L{3.4cm} Y l L{3.2cm}@{} } {4}
      { \textbf{Tool} & \textbf{Purpose} & \textbf{Version} & \textbf{Classification} } \l__swpm_rows_tl
    \subsection{Tool~Qualification}
    \__swpm_text:nn { ToolQualification } { \ph{ToolQualification} }
    \__swpm_free:n { environment }
  }

% ---- 9 Developer Manual --------------------------------------------------------
\cs_new_protected:Npn \__swpm_rule_row:nnn #1#2#3
  {
    \__swpm_check:nNnN {#3} \g__swpm_tool_prop { tool } \l__swpm_a_tl
    \tl_if_empty:NT \l__swpm_a_tl { \tl_set:Nn \l__swpm_a_tl { review } }
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl \exp_not:N \\ }
  }
\cs_new_protected:Npn \__swpm_ci_row:nnnn #1#2#3#4
  {
    \__swpm_check_opt:nNnN {#3} \g__swpm_tool_prop { tool } \l__swpm_a_tl
    \seq_put_right:Nn \l__swpm_chain_seq { {#1} {#3} }
    \tl_put_right:Nx \l__swpm_rows_tl
      { \exp_not:n { #1 & #2 & } \exp_not:V \l__swpm_a_tl & \__swpm_yesno:n {#4} \exp_not:N \\ }
  }
\tl_new:N \g__swpm_ht_goal_tl
\tl_new:N \g__swpm_ht_tools_tl
\tl_new:N \g__swpm_ht_steps_tl
\cs_new_protected:Npn \__swpm_step:nn #1#2
  {
    \item #1
    \tl_if_blank:nF {#2}
      {
        \par \colorbox{tcbg}
          { \parbox{\dimexpr\linewidth-2\fboxsep\relax} { \raggedright\ttfamily\small #2 } }
      }
  }
\cs_new_protected:Npn \__swpm_howto:nnn #1#2#3
  {
    \tl_gclear:N \g__swpm_ht_goal_tl
    \tl_gclear:N \g__swpm_ht_tools_tl
    \tl_gclear:N \g__swpm_ht_steps_tl
    \hbox_set:Nn \l_tmpa_box   % collect fields; stray text is discarded
      {
        \cs_set_protected:Npn \Goal ##1 { \tl_gset:Nn \g__swpm_ht_goal_tl {##1} }
        \cs_set_protected:Npn \Tools ##1 { \tl_gset:Nn \g__swpm_ht_tools_tl {##1} }
        \cs_set_protected:Npn \Step ##1##2
          { \tl_gput_right:Nn \g__swpm_ht_steps_tl { \__swpm_step:nn {##1} {##2} } }
        #3
      }
    \Needspace{6\baselineskip}
    \subsubsection{#2}\label{howto:#1}
    \tl_if_empty:NF \g__swpm_ht_goal_tl { \tl_use:N \g__swpm_ht_goal_tl \par }
    \tl_if_empty:NF \g__swpm_ht_tools_tl
      {
        \__swpm_check:VNnN \g__swpm_ht_tools_tl \g__swpm_tool_prop { tool } \l__swpm_a_tl
        \textbf{Tools:}~\l__swpm_a_tl \par
      }
    \tl_if_empty:NTF \g__swpm_ht_steps_tl
      { \ph{no~steps} }
      { \begin{enumerate}[itemsep=2pt] \tl_use:N \g__swpm_ht_steps_tl \end{enumerate} }
  }
\NewDocumentCommand \SpecDevelopment {}
  {
    \section{Developer~Manual}
    \subsection{Engineering~Rules}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_rules_seq { \__swpm_rule_row:nnn ##1 }
    \__swpm_table:nnnN { @{}L{2.8cm} Y L{3.6cm}@{} } {3}
      { \textbf{Area} & \textbf{Rule} & \textbf{Enforced~by} } \l__swpm_rows_tl
    \Needspace{10\baselineskip}
    \subsection{CI~Pipeline}
    \seq_clear:N \l__swpm_chain_seq
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_cistages_seq { \__swpm_ci_row:nnnn ##1 }
    \seq_if_empty:NF \l__swpm_chain_seq
      {
        Stages~of~every~pipeline~run,~in~order:
        \__swpm_chain:N \l__swpm_chain_seq
      }
    \__swpm_table:nnnN { @{}L{2.6cm} Y L{3.4cm} l@{} } {4}
      { \textbf{Stage} & \textbf{Does~/~checks} & \textbf{Tools} & \textbf{Blocking} } \l__swpm_rows_tl
    \subsection{Definition~of~Done}
    A~change~is~done~when:
    \__swpm_itemize:n { done }
    \subsection{How-tos}
    \seq_if_empty:NTF \g__swpm_howtos_seq { \ph{none} }
      { \seq_map_inline:Nn \g__swpm_howtos_seq { \__swpm_howto:nnn ##1 } }
    \__swpm_free:n { development }
  }
% ---- 10 Open Point List --------------------------------------------------------
\int_new:N \l__swpm_asof_int               % as-of date YYYYMMDD, 0: unknown
\int_new:N \l__swpm_op_r_int               % rank of the top-5 row being built
\str_new:N \l__swpm_op_want_str            % status of the list being built
\prop_new:N \l__swpm_rank_prop             % rank -> number of active points
\int_new:N \l__swpm_op_o_int
\int_new:N \l__swpm_op_p_int
\int_new:N \l__swpm_op_c_int
% #2 := #1 as integer YYYYMMDD, 0 if #1 is not YYYY-MM-DD
\cs_new_protected:Npn \__swpm_ymd:nN #1#2
  {
    \regex_extract_once:nnNTF { \A \s* (\d{4}) - (\d{1,2}) - (\d{1,2}) \s* \Z } {#1} \l__swpm_date_seq
      {
        \int_set:Nn #2
          {
            \seq_item:Nn \l__swpm_date_seq { 2 } * 10000
            + \seq_item:Nn \l__swpm_date_seq { 3 } * 100 + \seq_item:Nn \l__swpm_date_seq { 4 }
          }
      }
      { \int_zero:N #2 }
  }
\cs_generate_variant:Nn \__swpm_ymd:nN { VN }
\cs_new_protected:Npn \__swpm_op_asof:
  {
    \int_zero:N \l__swpm_asof_int
    \clist_map_inline:nn { OPLDate, DocDate }
      {
        \int_compare:nNnT \l__swpm_asof_int = 0
          {
            \prop_get:NnNT \g__swpm_meta_prop {##1} \l__swpm_tmp_tl
              { \__swpm_ymd:VN \l__swpm_tmp_tl \l__swpm_asof_int }
          }
      }
  }
% status cell, responsible \l__swpm_a_tl, date \l__swpm_b_tl
% (#1 status code, #2 raw status, #3 responsible, #4 date)
\cs_new_protected:Npn \__swpm_op_cells:nnnn #1#2#3#4
  {
    \str_case:nnF {#1}
      {
        {o} { \tl_set:Nn \l__swpm_c_tl { open } }
        {p} { \tl_set:Nn \l__swpm_c_tl { in~progress } }
        {c} { \tl_set:Nn \l__swpm_c_tl { closed } }
      }
      { \tl_set:Nn \l__swpm_c_tl { \__swpm_warn:n { #2~(unknown~status) } } }
    \bool_set:Nn \l_tmpa_bool { \str_if_eq_p:nn {#1} { c } }
    \tl_if_blank:nTF {#3}
      {
        \bool_if:NTF \l_tmpa_bool { \tl_set:Nn \l__swpm_a_tl { -- } }
          { \tl_set:Nn \l__swpm_a_tl { \__swpm_warn:n { responsible~missing } } }
      }
      { \tl_set:Nn \l__swpm_a_tl {#3} }
    \tl_if_blank:nTF {#4}
      {
        \bool_if:NTF \l_tmpa_bool { \tl_set:Nn \l__swpm_b_tl { -- } }
          { \tl_set:Nn \l__swpm_b_tl { \__swpm_warn:n { due~date~missing } } }
      }
      {
        \__swpm_ymd:nN {#4} \l_tmpa_int
        \int_compare:nNnTF \l_tmpa_int = 0
          { \tl_set:Nn \l__swpm_b_tl { \__swpm_warn:n { #4 \newline (not~a~date) } } }
          {
            \bool_lazy_and:nnTF
              { ! \l_tmpa_bool }
              { \int_compare_p:nNn \l__swpm_asof_int > \l_tmpa_int }
              { \tl_set:Nn \l__swpm_b_tl { \__swpm_warn:n { #4 \newline (overdue) } } }
              { \tl_set:Nn \l__swpm_b_tl {#4} }
          }
      }
  }
% "rank N given twice" if more than one active point has rank #1
\cs_new_protected:Npn \__swpm_op_rank_cell:n #1
  {
    \prop_get:NnNF \l__swpm_rank_prop {#1} \l__swpm_tmp_tl { \tl_set:Nn \l__swpm_tmp_tl { 0 } }
    \int_compare:nNnTF \l__swpm_tmp_tl > 1
      { \tl_set:Nn \l__swpm_d_tl { \__swpm_warn:n { \textbf{#1}~(twice) } } }
      { \tl_set:Nn \l__swpm_d_tl { \textbf{#1} } }
  }
% pass 1: counts, ranks of the active points
\cs_new_protected:Npn \__swpm_op_count:nnnnnnnnn #1#2#3#4#5#6#7#8#9
  {
    \str_if_eq:nnTF {#3} { c } { \int_incr:N \l__swpm_op_c_int }
      {
        \str_if_eq:nnTF {#3} { p } { \int_incr:N \l__swpm_op_p_int } { \int_incr:N \l__swpm_op_o_int }
        \int_compare:nNnT {#1} > 0
          {
            \prop_get:NnNF \l__swpm_rank_prop {#1} \l__swpm_tmp_tl { \tl_set:Nn \l__swpm_tmp_tl { 0 } }
            \prop_put:Nnx \l__swpm_rank_prop {#1} { \int_eval:n { \l__swpm_tmp_tl + 1 } }
          }
      }
  }
% top-5 table row: active points of rank \l__swpm_op_r_int
\cs_new_protected:Npn \__swpm_op_top_row:nnnnnnnnn #1#2#3#4#5#6#7#8#9
  {
    \bool_lazy_and:nnT
      { \int_compare_p:nNn {#1} = \l__swpm_op_r_int }
      { ! \str_if_eq_p:nn {#3} { c } }
      {
        \__swpm_op_cells:nnnn {#3} {#4} {#7} {#8}
        \__swpm_op_rank_cell:n {#1}
        \tl_put_right:Nx \l__swpm_rows_tl
          {
            \exp_not:V \l__swpm_d_tl & \exp_not:n { #5 & #6 & } \exp_not:V \l__swpm_c_tl
            & \exp_not:V \l__swpm_a_tl & \exp_not:V \l__swpm_b_tl \exp_not:n { & #9 } \exp_not:N \\
          }
      }
  }
% status list row: points of status \l__swpm_op_want_str (open also takes
% unknown statuses); top-5 points highlighted
\cs_new_protected:Npn \__swpm_op_row:nnnnnnnnn #1#2#3#4#5#6#7#8#9
  {
    \bool_lazy_or:nnT
      { \str_if_eq_p:Vn \l__swpm_op_want_str {#3} }
      { \bool_lazy_and_p:nn { \str_if_eq_p:Vn \l__swpm_op_want_str { o } } { \str_if_eq_p:nn {#3} { x } } }
      {
        \__swpm_op_cells:nnnn {#3} {#4} {#7} {#8}
        \int_compare:nNnTF {#1} > 0
          { \__swpm_op_rank_cell:n {#1} \tl_put_left:Nn \l__swpm_d_tl { \rowcolor{optop} } }
          { \tl_set:Nn \l__swpm_d_tl {#2} }
        \tl_set:Nn \l__swpm_x_tl {#6}
        \str_if_eq:nnT {#3} { x }
          { \tl_put_right:Nx \l__swpm_x_tl { \exp_not:N \newline \exp_not:V \l__swpm_c_tl } }
        \tl_put_right:Nx \l__swpm_rows_tl
          {
            \exp_not:V \l__swpm_d_tl \exp_not:n { & #5 & } \exp_not:V \l__swpm_x_tl & \exp_not:V \l__swpm_a_tl
            & \exp_not:V \l__swpm_b_tl \exp_not:n { & #9 } \exp_not:N \\
          }
      }
  }
% closed list row: a top rank on a closed point is red
\cs_new_protected:Npn \__swpm_op_closed_row:nnnnnnnnn #1#2#3#4#5#6#7#8#9
  {
    \str_if_eq:nnT {#3} { c }
      {
        \__swpm_op_cells:nnnn {#3} {#4} {#7} {#8}
        \int_compare:nNnTF {#1} > 0
          { \tl_set:Nn \l__swpm_d_tl { #5 \newline \__swpm_warn:n { (closed,~top~#1) } } }
          { \tl_set:Nn \l__swpm_d_tl { #5 #2 } }
        \tl_put_right:Nx \l__swpm_rows_tl
          {
            \exp_not:V \l__swpm_d_tl \exp_not:n { & #6 & } \exp_not:V \l__swpm_a_tl
            & \exp_not:V \l__swpm_b_tl \exp_not:n { & #9 } \exp_not:N \\
          }
      }
  }
\cs_new_protected:Npn \__swpm_op_list:nn #1#2   % status, subsection title
  {
    \Needspace{6\baselineskip}
    \subsection{#2}
    \str_set:Nn \l__swpm_op_want_str {#1}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_ops_seq { \__swpm_op_row:nnnnnnnnn ##1 }
    \__swpm_table:nnnN { @{}l L{1.5cm} Y L{2.4cm} L{1.9cm} Y@{} } {6}
      {
        \textbf{Top} & \textbf{ID} & \textbf{Topic} & \textbf{Responsible} & \textbf{Due}
        & \textbf{Comment}
      }
      \l__swpm_rows_tl
  }
\NewDocumentCommand \SpecOpenPoints {}
  {
    \clearpage
    \section{Open~Point~List}\label{swpm:opl}
    \__swpm_op_asof:
    \prop_clear:N \l__swpm_rank_prop
    \int_zero:N \l__swpm_op_o_int
    \int_zero:N \l__swpm_op_p_int
    \int_zero:N \l__swpm_op_c_int
    \seq_map_inline:Nn \g__swpm_ops_seq { \__swpm_op_count:nnnnnnnnn ##1 }
    Status~as~of~
    \prop_get:NnNTF \g__swpm_meta_prop { OPLDate } \l__swpm_tmp_tl
      { \tl_use:N \l__swpm_tmp_tl } { \__swpm_meta:n { DocDate } }
    \prop_get:NnNT \g__swpm_meta_prop { OPLSource } \l__swpm_tmp_tl
      { ,~source:~\tl_use:N \l__swpm_tmp_tl }
    .~\int_eval:n { \l__swpm_op_p_int + \l__swpm_op_o_int + \l__swpm_op_c_int }~points:~
    \int_use:N \l__swpm_op_p_int \c_space_tl in~progress,~
    \int_use:N \l__swpm_op_o_int \c_space_tl open,~
    \int_use:N \l__swpm_op_c_int \c_space_tl closed.~
    The~top~5~are~repeated~first~and~highlighted~in~the~status~lists.~A~due~date~
    before~the~as-of~date~is~marked~overdue.
    \Needspace{6\baselineskip}
    \subsection{Top~5}
    \tl_clear:N \l__swpm_rows_tl
    \int_step_inline:nn { 5 }
      {
        \int_set:Nn \l__swpm_op_r_int {##1}
        \seq_map_inline:Nn \g__swpm_ops_seq { \__swpm_op_top_row:nnnnnnnnn ####1 }
      }
    \__swpm_table:nnnN { @{}l L{1.5cm} Y l L{2.2cm} L{1.9cm} Y@{} } {7}
      {
        \textbf{Top} & \textbf{ID} & \textbf{Topic} & \textbf{Status} & \textbf{Responsible}
        & \textbf{Due} & \textbf{Comment}
      }
      \l__swpm_rows_tl
    \__swpm_op_list:nn { p } { In~Progress }
    \__swpm_op_list:nn { o } { Open }
    \Needspace{6\baselineskip}
    \subsection{Closed}
    \tl_clear:N \l__swpm_rows_tl
    \seq_map_inline:Nn \g__swpm_ops_seq { \__swpm_op_closed_row:nnnnnnnnn ##1 }
    \__swpm_table:nnnN { @{}L{1.5cm} Y L{2.4cm} L{1.9cm} Y@{} } {5}
      { \textbf{ID} & \textbf{Topic} & \textbf{Responsible} & \textbf{Closed} & \textbf{Result} }
      \l__swpm_rows_tl
    \__swpm_free:n { opl }
  }
\ExplSyntaxOff

% ------------------------------------------------------------ diagram styles ---
\colorlet{swpmbox}{accent!12}
\tikzset{
  swpm/role/.style  = {draw=accent, fill=swpmbox, rectangle, align=center, anchor=north,
                       font=\small, text width=3.2cm, minimum height=1.2cm, inner sep=3pt,
                       execute at begin node={\hyphenpenalty=10000 }}, % no hyphenation
  swpm/edge/.style  = {accent, thick},
  swpm/state/.style = {draw=accent, fill=swpmbox, rounded corners, align=center,
                       font=\small, text width=2.3cm, minimum height=1.0cm, inner sep=3pt,
                       execute at begin node={\hyphenpenalty=10000 }},
  swpm/flow/.style  = {-{Stealth}, accent, thick},
  swpm/time/.style  = {-{Stealth}, accent, very thick},
  swpm/ms/.style    = {draw=accent, fill=accent, diamond, inner sep=2.2pt},
  swpm/rel/.style   = {draw=accent, fill=white, regular polygon, regular polygon sides=3,
                       inner sep=1.4pt, thick},
  swpm/tick/.style  = {accent!60, thin},
  swpm/tlabel/.style= {font=\scriptsize, align=center, inner sep=1.5pt},
  swpm/cell/.style  = {draw=white, line width=1.5pt, minimum width=3.2cm, minimum height=1.5cm,
                       text width=2.9cm, align=center, font=\small\bfseries},
}
\endinput
