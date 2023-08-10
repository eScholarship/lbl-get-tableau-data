# Get LBL Tableau Dashboard Data

## Usage:
1. Download the new OSTI FY .xlsx files, and put them in the "osti_files" folder.
2. Run the program -- it will:
    1. Create a folder inside of "output", named with today's date. All the files will be saved here.
    2. Connect to LBL's HR Feed API, and download a CSV.
    3. Connect to the Reporting DB, run each of the queries contained in the "sql_queries" folder, and save a CSV for each one.
    4. For each of the new OSTI .xlsx workbooks, it will export the worksheet named 'LBNL' to CSV.

Once you've got everything, copy these files into the Dashboard's "Tableau Data" folder, replacing the older files.