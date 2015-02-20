package main

import (
	"koding/db/models"
	"koding/db/mongodb/modelhelper"

	"labix.org/v2/mgo/bson"
)

type EnvData struct {
	Own           []*MachineAndWorkspaces
	Shared        []*MachineAndWorkspaces
	Collaboration []*MachineAndWorkspaces
}

type MachineAndWorkspaces struct {
	Machine    models.Machine
	Workspaces []*models.Workspace
}

func getEnvData(userInfo *UserInfo) (*EnvData, error) {
	ownMachines, err := getOwnMachines(userInfo.UserId)
	if err != nil {
		return nil, err
	}

	sharedMachines, err := getSharedMachines(userInfo.UserId)
	if err != nil {
		return nil, err
	}

	envData := &EnvData{
		Own:    getWorkspacesForEachMachine(ownMachines),
		Shared: getWorkspacesForEachMachine(sharedMachines),
	}

	return envData, nil
}

func getOwnMachines(userId bson.ObjectId) ([]models.Machine, error) {
	return modelhelper.GetOwnMachines(userId)
}

func getSharedMachines(userId bson.ObjectId) ([]models.Machine, error) {
	return modelhelper.GetSharedMachines(userId)
}

func getWorkspacesForEachMachine(machines []models.Machine) []*MachineAndWorkspaces {
	mws := []*MachineAndWorkspaces{}

	for _, machine := range machines {
		machineAndWorkspace := &MachineAndWorkspaces{
			Machine: machine,
		}

		workspaces, err := modelhelper.GetWorkspacesForMachine(machine.ObjectId)
		if err != nil {
			machineAndWorkspace.Workspaces = workspaces
		}

		mws = append(mws, machineAndWorkspace)
	}

	return mws
}
