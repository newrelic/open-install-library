use admin;
db.createRole({role: "listCollections", privileges: [{resource: {db:"",collection:""},actions: ["listCollections"]}],roles: []})
db.createUser({user: "newrelic", pwd: "Virtuoso4all!", roles: ["clusterMonitor","listCollections"]})
