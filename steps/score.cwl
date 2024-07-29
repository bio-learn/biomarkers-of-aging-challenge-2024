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
        import argparse
        import json
        from biolearn.data_library import GeoData
        from biolearn.mortality import calculate_mortality_hazard_ratios
        import pandas as pd

        print(f"Parsing Arguments")
        parser = argparse.ArgumentParser()
        parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
        parser.add_argument("-r", "--results", required=True, help="Scoring results")
        parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

        args = parser.parse_args()

        result = {'hr': 1, "pval": 1, 'submission_status': "SCORED"}

        # Write result
        with open(args.results, 'w') as o:
            o.write(json.dumps(result))

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
    dockerPull: boac-eval:latest
