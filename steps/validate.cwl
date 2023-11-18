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

        parser = argparse.ArgumentParser()
        parser.add_argument("-r", "--results", required=True, help="Validation results")
        parser.add_argument("-e", "--entity_type", required=True, help="Synapse entity type downloaded")
        parser.add_argument("-s", "--submission_file", help="Submission File")

        args = parser.parse_args()

        if args.submission_file is None:
            prediction_file_status = "INVALID"
            invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
        else:
            invalid_reasons = []
            try:
                with open(args.submission_file, newline='') as csvfile:
                    reader = csv.DictReader(csvfile)
                    required_columns = {'sampleId', 'predictedAge'}
                    columns = set(reader.fieldnames)

                    # Check for required columns
                    if not required_columns.issubset(columns):
                        missing_columns = required_columns - columns
                        found_columns = ', '.join(columns)  # List of found columns
                        invalid_reasons.append(f"Missing required columns: {', '.join(missing_columns)}. Found columns: {found_columns}")
                        prediction_file_status = "INVALID"
                    else:
                        # Check if 'predictedAge' contains only numbers
                        for row in reader:
                            try:
                                float(row['predictedAge'])  # Attempt to convert to float
                            except ValueError:
                                invalid_reasons.append("'predictedAge' column must contain only numbers")
                                prediction_file_status = "INVALID"
                                break

                        if not invalid_reasons:
                            prediction_file_status = "VALIDATED"
            except Exception as e:
                # Handle file reading and parsing errors
                invalid_reasons.append(str(e))
                prediction_file_status = "INVALID"

        result = {'submission_errors': "\n".join(invalid_reasons),
                  'submission_status': prediction_file_status}

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
