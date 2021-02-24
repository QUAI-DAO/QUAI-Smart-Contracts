import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy("BSC_QUAI_Token", {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
    });
};

export default func;
export const tags = ["BSC_QUAI_Token"];
