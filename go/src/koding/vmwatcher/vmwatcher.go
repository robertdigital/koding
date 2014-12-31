package main

import (
	"koding/db/models"
	"koding/db/mongodb/modelhelper"
	"log"
)

// pops username from set in db and gets metrics for machines belonging
// to that user; it uses pop instead of find so multiple workers can
// work in parallel
func getAndSaveQueueMachineMetrics() error {
	for {
		for _, metric := range metricsToSave {
			machines, err := popMachinesForMetricGet(metric.GetName())
			if err != nil {

				// ran out of usernames in queue, so return
				if isRedisRecordNil(err) {
					return nil
				}
			}

			if len(machines) == 0 {
				log.Println(err)
				continue
			}

			for _, machine := range machines {
				err := metric.GetAndSaveData(machine.Credential)
				if err != nil {
					log.Println(err)
				}
			}
		}
	}

	return nil
}

func stopMachinesOverLimit() error {
	for _, metric := range metricsToSave {
		machines, err := metric.GetMachinesOverLimit()
		if err != nil {
			log.Println(err)
			continue
		}

		for _, machine := range machines {
			err = stopVm(machine.ObjectId.Hex())
			if err != nil {
				log.Println(err)
			}
		}
	}

	return nil
}

func queueUsernamesForMetricGet() error {
	machines, err := getRunningVms()
	if err != nil {
		return err
	}

	if len(machines) == 0 {
		return nil
	}

	usernames := []interface{}{}
	for _, machine := range machines {
		usernames = append(usernames, machine.Credential)
	}

	for _, metric := range metricsToSave {
		err := storage.Queue(metric.GetName(), usernames)
		if err != nil {
			return err
		}
	}

	return nil
}

func popMachinesForMetricGet(metricName string) ([]*models.Machine, error) {
	username, err := storage.Pop(metricName)
	if err != nil {
		return nil, err
	}

	machines, err := modelhelper.GetMachinesForUsername(username)
	if err != nil {
		return nil, err
	}

	return machines, nil
}

func getRunningVms() ([]*models.Machine, error) {
	return modelhelper.GetRunningVms()
}
