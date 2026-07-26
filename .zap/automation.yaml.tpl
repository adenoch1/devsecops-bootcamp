env:
  contexts:
    - name: staging-authenticated
      urls:
        - "__TARGET_URL__"
      includePaths:
        - "__TARGET_URL__.*"
  parameters:
    failOnError: true
    failOnWarning: false
jobs:
  - type: replacer
    parameters:
      rules:
        - description: bearer-token
          matchType: REQ_HEADER
          matchString: Authorization
          replacementString: "Bearer __AUTH_TOKEN__"
  - type: spider
    parameters:
      context: staging-authenticated
      maxDuration: 5
  - type: activeScan
    parameters:
      context: staging-authenticated
      maxScanDurationInMins: 20
  - type: report
    parameters:
      template: traditional-json
      reportDir: /zap/wrk
      reportFile: zap-active-report.json
