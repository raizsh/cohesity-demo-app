// Copyright 2022 Cohesity Inc.
//

package main

import "github.com/raizsh/cohesity-demo-app/server"

func main() {
  rs := demoapp.NewDemoAppServer()
  rs.Start()
}
