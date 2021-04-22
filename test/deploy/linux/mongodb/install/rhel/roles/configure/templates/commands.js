use admin;
db.createRole({role: "listCollections", privileges: [{resource: {db:"admin",collection:""},actions: ["listCollections"]}],roles: []})
db.createUser({user: "newrelic", pwd: "Virtuoso4all!", roles: ["clusterMonitor","listCollections"]})