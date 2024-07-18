#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: Score predictions file

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
    - entryname: score.py
      entry: |
        #!/usr/bin/env python
        import subprocess
        import sys
        import argparse
        import json

        print(f"Installing Packages")

        # Function to install packages
        def install(package):
            subprocess.check_call([sys.executable, "-m", "pip", "install", package])

        # Install required packages
        install("biolearn==0.4.4")
        install("pandas")

        import pandas as pd
        from biolearn.data_library import GeoData
        from biolearn.mortality import calculate_mortality_hazard_ratios

        print(f"Parsing Arguments")
        parser = argparse.ArgumentParser()
        parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
        parser.add_argument("-r", "--results", required=True, help="Scoring results")
        parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

        args = parser.parse_args()

        print(f"Calculating Score")
        try:
            # Calculate Score
            gold_standard = GeoData(pd.read_csv(args.goldstandard, index_col=0), None, None)
            submitted_predictions = pd.read_csv(args.submissionfile, index_col=0)
            hazard_ratios = calculate_mortality_hazard_ratios(gold_standard, submitted_predictions)

            # Extract data
            hr_value = hazard_ratios.iloc[0]['HR']
            pval_value = hazard_ratios.iloc[0]['P_value']
            result = {'hr': hr_value, 'pval': pval_value, 'submission_status': "SCORED"}

        except Exception as e:
            result = {'submission_status': "ERROR"}
            print(f"An error occurred: {e}")

        # Write result to JSON file
        with open(args.results, 'w') as o:
            o.write(json.dumps(result))

        print(f"Results saved to {args.results}")

inputs:
  - id: input_file
    type: File
  - id: goldstandard
    type: File
  - id: check_validation_finished
    type: boolean?

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: status
    type: string
    outputBinding:
      glob: results.json
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])
      loadContents: true

baseCommand: python
arguments:
  - valueFrom: score.py
  - prefix: -f
    valueFrom: $(inputs.input_file.path)
  - prefix: -g
    valueFrom: $(inputs.goldstandard.path)
  - prefix: -r
    valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: python:3.9.1-slim-buster
