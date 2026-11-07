// Every check the chat server ships for a deployment, run over this deployment's own chat.json
// and page: the three-place pin, chat.json's shape against deployment.json, and the rendered page.
import { registerDeploymentTests } from "companygraph-chat-server/deploy/tests";

registerDeploymentTests();
