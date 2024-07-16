# Development workplan
7/15/24

This work builds on apantazi's prior work (see [prior repo](https://github.com/apantazi/legislator_dashboard/tree/main)) by managing data in a Postgres database, integrating new sources of data, tracking historical changes in data, and improving the app's maintainability and scalability. I'm improving data integrity and reliability by re-shaping nested lists (from API-acquired JSONs and R scripts) into relational database format and creating curated views of processed data. My intent is to make it easier for web app developers and data visualization specialists to:
* create **new visualizations using any programming language** (not just R) and connecting via Postgres/SQL or loading CSV files
* quickly **adapt to data elements** that change over time (e.g. district demographics)
* highlight **contextual data** (e.g. demographics and district electoral preferences) related to legislator voting records
* address all **deduplicating and data cleaning** prior to app design phase
* provide app developers with greater control over the presentation of data including sorting, hover text formatting, and filtering
* adapt existing reporting tools to different jurisdictions besides the state of Florida- for example, Jacksonville city council (via LegiStar data)

Some early updates to the app include addition of sorting, filtering by bill topic, and a new tab comparing legislator voting records to their district's voting preferences and demographics.

Following are some data pipeline maintenance tasks:
* Improve documentation- data dictionary for app #3, all calculated fields in p_* layer (see first and last sections of 03_transform)
* Continue reconciling recordcounts and account for all disparities between tables/ calculation data frames
* Improve data integrity by reviewing/updating data types
* Include alternate partisanship metrics (including [nominate](https://en.wikipedia.org/wiki/NOMINATE_(scaling_method)))
* Automate API requests via Github actions to keep legislative voting data up-to-date during Fall legislative session
* Deploy Postgres database to Heroku (for testing), then Azure (for production)

And some expansions to the data pipeline:
* Incorporate LegiStar voting data for Jacksonville and align this with state data, so it can be visualized with existing web apps

Each tab in the legislative voting dashboard also contains its own development notes:
* [District Context](https://docs.google.com/document/d/1e3KDrnpXjKL4OJqFR49hqti77TntPRL7k4AkqSfsefU/edit?usp=drive_link) development notes
* [Voting Patterns](https://docs.google.com/document/d/1OGiJH7B_0j3B38gEtgt_FDhkxzL84ZtGistdup2yYHI/edit?usp=drive_link) development notes
