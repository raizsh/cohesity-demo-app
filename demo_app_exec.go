// Copyright 2022 Cohesity Inc.
//

package main

import "github.com/raizsh/cohesity-demo-app/demoapp"

func main() {
  rs := demoapp.NewDemoAppServer()
  rs.Start()
}
