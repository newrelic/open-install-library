rs.inititate();
use admin;
db.createRole({role: "listCollections", privileges: [{resource: {db:"",collection:""},actions: ["listCollections"]}],roles: []})
db.createUser({user: "username", pwd: "password", roles: ["clusterMonitor","listCollections"]})
