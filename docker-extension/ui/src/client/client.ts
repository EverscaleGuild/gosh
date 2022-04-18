import {
  Image,
  Container
 } from "../interfaces";

const logger = console;

const METADATA_KEY_BUILD_PROVIDER = "WALLET_PUBLIC";
const COMMAND_VALIDATE_IMAGE_SIGNATURE = "/command/ensure-image-signature.sh" 
const UNSIGNED_STATUS = "error";

declare global {
  interface Window {
    ddClient: {
      docker: {
        listContainers: () => Promise<Array<any>>,
        listImages: () => Promise<Array<any>>
      },
      extension: any
    };
  }
}


export class DockerClient {

  /**
   * Get containers list
   **/
  static async getContainers(): Promise<Array<Container>> {
    const containers = await window.ddClient.docker.listContainers();
    const containersViewModel:Array<Container> = [];
    for (var i=0; i < containers.length; i++) {
      const container = containers[i];
      const containerName = container.Names.length > 0 ? container.Names[0] : container.Id;
      const [isSigned, buildProvider] = await DockerClient.getBuildProvider(container);
      const digestId = await DockerClient.getContainerDigestId(container);
      const verificationStatus = isSigned ? 
        await DockerClient.getImageStatus(buildProvider, digestId)
        : UNSIGNED_STATUS;
      containersViewModel.push({
        validated: verificationStatus,
        id: container.Id,
        containerHash: container.Id,
        containerName: containerName,
        imageHash: container.ImageID,
        buildProvider: buildProvider,
        goshRootAddress: ""
      });
    }
    return containersViewModel;
  }

  static readImageDigest(image: any): string {
    if (!!image.RepoDigests && image.RepoDigests.length > 0) {
      const digest = image.RepoDigests[0];
      if (digest.includes('@')) {
        return digest.split('@')[1];
      } else {
        return digest;
      }
    } else {
      return "";
    }
  }

  static async getContainerDigestId(container: any): Promise<string> {
    const images = await window.ddClient.docker.listImages();
    for (let i = 0; i < images.length; i++) {
      if (images[i].Id == container.ImageID) {
        return DockerClient.readImageDigest(images[i]);
      }
    }
    return "";
  }

  /**
   * Get containers list
   **/
  static async getImages(): Promise<Array<Image>> {
    const images = await window.ddClient.docker.listImages();
    const imagesViewModel: Array<Image> = [];
    for (var i=0; i < images.length; i++) {
      const image = images[i];
      const [isSigned, buildProvider] = await DockerClient.getBuildProvider(image);
      const digestId = DockerClient.readImageDigest(image);
      const verificationStatus = isSigned ? 
        await DockerClient.getImageStatus(buildProvider, digestId)
        : UNSIGNED_STATUS;
      imagesViewModel.push({
        validated: verificationStatus,
        id: image.Id,
        imageHash: image.Id,
        buildProvider: buildProvider,
        goshRootAddress: ""
      });
    }
    return imagesViewModel;
  }

  /**
   * Get image state
   **/
  static async getImageStatus(buildProviderPublicKey: string, imageHash: string): Promise<any> {
    logger.log(`Calling getImageStatus: pubkey - ${buildProviderPublicKey}  digest: ${imageHash}...\n`);
    try {
      const result = await window.ddClient.extension.vm.cli.exec(
        COMMAND_VALIDATE_IMAGE_SIGNATURE,
        [buildProviderPublicKey, imageHash]
      );
      const resultText = result.stdout.trim(); 
      logger.log(`Result: <${resultText}>\n`);
      // Note: 
      // There was a check for result.code == 0 that didn't work
      // For some reason it is not working as expected and returns undefined 
      const verificationStatus =  resultText == "true";
      return verificationStatus ? "success" : "error";
    } 
    catch (e) {
        console.log("image validaton failed", e); 
        return "warning";
    }
  }

  static async getBuildProvider(container: any): Promise<[boolean, string]> {
    const metadata = container.Labels || {};
    if (METADATA_KEY_BUILD_PROVIDER in metadata) {
      return [true, metadata[METADATA_KEY_BUILD_PROVIDER]];
    } else {
      return [false, "-"];
    }
  }
}

export default DockerClient;

