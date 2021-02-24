import fs from "fs";

// networks to consider
const networks = [
    { id: "1", name: "mainnet" },
    { id: "4", name: "rinkeby" },
    { id: "5", name: "goerli" },
    { id: "42", name: "kovan" },
    { id: "97", name: "bsc_testnet" },
];

// files to ignore
const ignore = ["Migrations.json"];

// read files in the truffle build dir
let files = fs.readdirSync("build/contracts");

// remove ignored files
files = files.filter((file) => ignore.indexOf(file) == -1);

// process each file
files.forEach((file) => {
    const contract = require(`./build/contracts/${file}`);
    networks.forEach((network) => {
        const deployment = contract.networks[network.id];
        if (deployment) {
            const buidler = {
                contractName: contract.contractName,
                abi: contract.abi,
                address: deployment.address,
                transactionHash: deployment.transactionHash,
                bytecode: contract.bytecode,
                deployedBytecode: contract.deployedBytecode,
                userdoc: contract.userdoc,
                devdoc: contract.devdoc,
            };
            const output = `deployments/${network.name}/${file}`;
            console.log(`Writing ${output}`);
            fs.writeFileSync(output, JSON.stringify(buidler, null, 2));

            // write .chainId file
            fs.writeFileSync(
                `deployments/${network.name}/.chainId`,
                network.id
            );
        }
    });
});
