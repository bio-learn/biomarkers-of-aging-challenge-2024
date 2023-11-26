#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: Validate predictions file

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
    - entryname: validate.py
      entry: |
        #!/usr/bin/env python
        import argparse
        import json
        import csv

        def read_csv(filename):
            """ Read a CSV file and return a dictionary mapping from the first column to the second column. """
            data = {}
            with open(filename, newline='') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    data[row['sampleId'].strip()] = float(row[next(iter(row.keys() - {'sampleId'}))].strip())
            return data

        def calculate_mean_average_error(submission, goldstandard):
            """ Calculate the mean average error between submission and goldstandard. """
            errors = []
            for sample_id, predicted_age in submission.items():
                if sample_id in goldstandard:
                    error = abs(predicted_age - goldstandard[sample_id])
                    errors.append(error)
            return sum(errors) / len(errors) if errors else None

        parser = argparse.ArgumentParser()
        parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
        parser.add_argument("-r", "--results", required=True, help="Scoring results")
        parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

        args = parser.parse_args()

        # Read submission file and gold standard file
        submission_data = read_csv(args.submissionfile)
        goldstandard_data = read_csv(args.goldstandard)

        # Calculate mean average error
        mae = calculate_mean_average_error(submission_data, goldstandard_data)

        # Prepare result
        prediction_file_status = "SCORED" if mae is not None else "ERROR"
        result = {'mae': mae, 'submission_status': prediction_file_status}

        # Write result
        with open(args.results, 'w') as o:
            o.write(json.dumps(result))


inputs:
  - id: input_file
    type: File?
  - id: entity_type
    type: string

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
  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
      loadContents: true

baseCommand: python
arguments:
  - valueFrom: validate.py
  - prefix: -s
    valueFrom: $(inputs.input_file)
  - prefix: -e
    valueFrom: $(inputs.entity_type)
  - prefix: -r
    valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: python:3.9.1-slim-buster
