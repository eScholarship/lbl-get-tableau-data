# Get LBL Tableau Dashboard Data

## Required external py libraries
This program uses a few external libraries, which should all be available via pip:
1. [requests](http://requests.readthedocs.org/en/latest/): Handles HTTP requests
2. [pyodbc](https://github.com/mkleehammer/pyodbc/wiki): Handles the SQL
3. [openpyxl](https://openpyxl.readthedocs.io/en/stable/): Handles XLSX excell files.
4. Various google drive API packages.

## NOTE: Required Google Drive API file: token.json
This program requires a file "token.json" to connect to the Google Drive API. (This file is on subi currenlty.) It is possible this token may expire or break at some point, and a new token.json will need to be generated. If this occurs, see [Google's Python Quickstart guide](https://developers.google.com/drive/api/quickstart/python). The basic workflow is: (1) Install the required Google Drive py packages; (2) run this quickstart .py program, which will prompt you to sign in to your google account; (3) This will save "credentials.json" to your hard drive, and generate "token.json"

## Usage:
- This program can be run on subi or on your desktop.
- It is currently installed on subi staging, and chrontabbed to run monthly.
- If you want to convert the OSTI .xslx files, download them into a folder called "input_osti_xlsx_files/". Run the program with -fy to convert these.
- Run with -g to upload the resulting output files to LBL's "Tableau Data" google drive.

### Running the program will:
1. Create a folder inside of "output", named YYYY-MM-DD-HH-MM-SS/. All the files will be saved here.
2. Connect to LBL's HR Feed API, and download a CSV.
3. Connect to the Elements Reporting DB, run each of the queries contained in the "sql_queries" folder, and save a CSV for each one.
4. If you're running with -fy, it'll check for the osti xlsx files and extract the appropriate sheet into a CSV.
5. If you're running with -g, it'll ping the "Tableau Data" on google drive,
    1. If files with matching names exist, it'll overwrite them with the new files
    2. If they don't exist, it'll upload the new files.
6. If you're running without -g, the output files will be available in the output folder.
