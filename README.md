# Get LBL Tableau Dashboard Data

## Required external py libraries
This program uses 3 external libraries, which should all be available via pip:
1. [requests](http://requests.readthedocs.org/en/latest/): Handles HTTP requests
2. [pyodbc](https://github.com/mkleehammer/pyodbc/wiki): Handles the SQL
3. [openpyxl](https://openpyxl.readthedocs.io/en/stable/): Handles XLSX excell files.

## Usage:
1. Download the new OSTI FY .xlsx files, and put them in the "input_osti_xlsx_files" directory.
(If last month's files are still there, remove them first.)
2. Run the program. It will:
    1. Create a folder inside of "output", named with today's date. All the files will be saved here.
    2. Connect to LBL's HR Feed API, and download a CSV.
    3. Connect to the Elements Reporting DB, run each of the queries contained in the "sql_queries" folder, and save a CSV for each one.
    4. For each of the new OSTI .xlsx workbooks, it will export the worksheet named 'LBNL' to CSV.

When the program is complete, copy the files from the output folder to the "Tableau Data" folder, replacing the older files.