// Every check the server ships for a deployment, run over this deployment's own snapshot and
// page: the three-place pin, the tools against the snapshot, and the rendered page.
import { registerDeploymentTests } from "companygraph-mcp-server/deploy/tests";

registerDeploymentTests();
