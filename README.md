DataExtractor
=============

DataExtractor tool

Copyright © 2012-2019 GiGL, TVERC, SBIC

Overview
--------
DataExtractor is a MapBasic tool and associated SQL scripts to extract biodiversity information from SQL Server and MapInfo GIS layers for pre-defined spatial areas. The output files can be created as MapInfo TAB format (.tab) files, ESRI Shapefile (.shp) files and/or Comma Separated Value (.csv) files and can be combined together, if required, as compressed (.zip) files.

Requirements
------------
The DataExtractor tool requires the following:

 - MapInfo 10.0 or higher

 - Microsoft SQL Server 2008 Express Edition or later, OR
 - Microsoft SQL Server 2008 or later

Local output staging (v1.7.05)
-----------------------------

To create outputs locally before transferring them to their final destination,
add the following setting under `DataExtractor` in the profile XML:

```xml
<WorkingDir>
  <value>C:\DataExtractor\Working</value>
</WorkingDir>
```

A missing or blank `WorkingDir` keeps direct output to `DefaultPath`.
When enabled, each run creates a fresh folder under `WorkingDir`. Each partner's
outputs use the usual partner and format subfolders within that run folder.
Exports, macros and optional ZIP creation finish locally before that partner's
folder is moved to `DefaultPath`. Output tables are closed before packaging and
transfer. Run messages are written to a temporary journal in the working run
folder and retained in memory. At the end of the whole run, the accumulated
messages are appended to the separate main log at `LogFilePath`. Missing or
blank `WorkingDir` puts the temporary journal in `LogFilePath` instead.

Translator mapping files, translator logs, EasyLoader logs and export-macro logs
also use the working run folder. Macro messages are imported into the journal
and memory buffer. At the end, top-level diagnostics are moved to `LogFilePath`;
unfinished partner outputs stay local. Logging continues at the journal's new
location after a successful move. If final-log publication fails, pending messages
and the journal are retained and a later run must publish the pending messages
before beginning. The existing main-log archive option remains available.

Transfers use Windows Robocopy, with three retries and a two-second delay.
Existing files with matching output names are overwritten; unrelated files in
the destination are retained. A failed transfer stops further processing and
leaves untransferred local files available at the location recorded in the log.
A transfer can partially succeed, so check both locations when recovering files.
Cancelled runs also retain unfinished local outputs. Later runs use a fresh
folder and do not automatically include retained files. Empty run folders are
removed after processing.

ZIP handling is compiled into the MapBasic application. It calls Windows'
built-in `tar.exe` and `fc.exe` directly, using ordinary user permissions.
There is no PowerShell or script-host dependency and no additional ZIP helper
file to deploy. The tool checks executable availability before processing a
ZIP-enabled run and locates the native Windows tools correctly from 32-bit
MapInfo on 64-bit Windows. The destination organisation must allow those tools.

The tool snapshots the partner's file inventory and creates a candidate archive
in a separate temporary folder. It checks the ZIP signature, extracts the archive
and compares every restored file byte for byte with its original. It also checks
the inventories, file sizes and source modification times. Only a verified archive
replaces the previous ZIP, using a same-volume rename. Source cleanup removes
only the recorded files and empty directories. Failed verification/publication
retains the previous archive and originals; failed source cleanup can leave a
verified new ZIP alongside remaining files. The log identifies recovery folders.
Links and junctions in a partner's output tree are rejected.

Verification requires room for both the candidate ZIP and an extracted copy of
the outputs. It avoids compression dialogs and polling delays, but no comparative
speed claim has been measured. Older Windows systems without the required native
tools cannot use ZIP output. The existing `zip.vbs` is retained unchanged for
legacy binaries; the updated application does not call it.

Selection and output-name validation (v1.7.05)
---------------------------------------------

MapInfo extracts check geometry only for the selected partner. Non-spatial
rows belonging to other partners do not disable boundary filtering. Where a
partner has both spatial and non-spatial rows, its spatial boundaries are used.
A selected partner with no geometry retains the existing attribute-only
selection behaviour; the log identifies that choice. A partner removed since
the form was opened is reported and its MapInfo output is skipped. Ordinary
spatial MapInfo selection retains whole features rather than clipping them.

Before extraction or partner upload, the tool expands output names and checks
the resulting destinations, including the 31-character base-name limit,
case-insensitive matches, intermediate TAB files and requested SHP/CSV/TXT
outputs. Conflicting requested outputs stop the run and identify both
definitions in the log. Normal replacement of the same output on a later run
is unchanged. The check covers configured tool outputs; a custom macro must
manage any additional files it creates.

Build and verification
----------------------

Recompile all MapBasic modules and link `DataExtractor.mbp` using the
MapBasic version and 32/64-bit include settings appropriate to your deployment.
The checked-in `.MBO` and `.MBX` files are not updated by source edits.
No ZIP helper scripts need deploying with the rebuilt application. Python
standard-library tests exercise the command lines taken from the MapBasic source,
native archive/comparison tools, format/content checks and archive replacement:
`python -m unittest discover -s tests -v`. These do not execute the MapBasic
orchestration, which still needs compilation and testing inside MapInfo.

Before deployment, check in MapInfo with a test profile and test destinations:

- Run with `WorkingDir` missing, blank and populated.
- Extract a spatial partner while an unrelated inactive or unselected partner
  has no geometry; only the selected boundary should filter the results.
- Test a selected partner with no geometry, mixed spatial/non-spatial rows,
  and a partner removed after the form opened. Check the selected path and log.
- Request two output names with the same first 31 expanded characters, names
  differing only in case, and a SQL/map pair targeting the same file. Each
  conflicting run must stop before extraction or upload and leave prior
  outputs untouched. Repeat with distinct partner folders and names that
  remain unique after expansion; these runs should proceed normally.
- Select two partners with different output folders, using SQL and map layers,
  TAB/SHP/CSV/TXT outputs and any export macros used in production.
- Repeat with ZIP creation enabled. Each ZIP must contain only its own partner's
  outputs, including the first partner and the final partner.
- Test ZIP tool availability/organisation policy, 32-bit and 64-bit MapInfo,
  existing ZIP replacement, accented/special filenames, nested and empty folders,
  file locks, changed source files and insufficient verification disk space.
  Check that failed runs retain the original files/recovery paths and that
  successful verification removes only that partner's source outputs.
- Include a non-spatial SQL TAB output and an extract with no matching records,
  including a skipped final extract. Check that tables close and completed
  partner outputs still reach the destination.
- Repeat an extract into an existing destination; check replacement files and
  retention of unrelated files.
- Make a destination unavailable or lock an output during transfer. Check the
  error log, retained local files and that subsequent partners are not processed.
- Cancel a multi-partner run and rerun it. Earlier completed partners should
  already be delivered, and abandoned local outputs must not enter the new run.
- Check the temporary log during processing, then the final log after the whole
  run. Test unavailable log destinations, macro output capture, and retained
  memory messages before starting another run. Confirm translator files stay
  local during processing and reach `LogFilePath` at the end.

Source Code
-----------
The source code for the DataExtractor tool is open source and can be downloaded from:
<https://github.com/LERCAutomation/DataExtractor-MapInfo>

License Information
-------------------
The DataExtractor tool is free software. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

See the file "License.txt" supplied with the source files for information on the
terms & conditions for usage and copying, and a DISCLAIMER OF ALL WARRANTIES
or see <http://www.gnu.org/licenses> for more details of the GNU General Public
License.

Funding
-------
The DataExtractor tool was developed with funding from:

* Greenspace Information for Greater London CIC
* Thames Valley Environmental Records Centre
* Surrey Biodiversity Information Centre
