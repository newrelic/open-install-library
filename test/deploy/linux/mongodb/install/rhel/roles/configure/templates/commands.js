use admin;
db.createRole({role: "listCollections", privileges: [{resource: {db:"admin",collection:""},actions: ["listCollections"]}],roles: []})
db.createUser({user: "username", pwd: "password", roles: ["clusterMonitor","listCollections"]})