/************************************************************************************************
  Copyright(C)2023 Hesai Technology Co., Ltd.
  All code in this repository is released under the terms of the following [Modified BSD License.]
  Modified BSD License:
  Redistribution and use in source and binary forms,with or without modification,are permitted 
  provided that the following conditions are met:
  *Redistributions of source code must retain the above copyright notice,this list of conditions 
   and the following disclaimer.
  *Redistributions in binary form must reproduce the above copyright notice,this list of conditions and 
   the following disclaimer in the documentation and/or other materials provided with the distribution.
  *Neither the names of the University of Texas at Austin,nor Austin Robot Technology,nor the names of 
   other contributors maybe used to endorse or promote products derived from this software without 
   specific prior written permission.
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGH THOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
  WARRANTIES,INCLUDING,BUT NOT LIMITED TO,THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
  PARTICULAR PURPOSE ARE DISCLAIMED.IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
  ANY DIRECT,INDIRECT,INCIDENTAL,SPECIAL,EXEMPLARY,OR CONSEQUENTIAL DAMAGES(INCLUDING,BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;LOSS OF USE,DATA,OR PROFITS;OR BUSINESS INTERRUPTION)HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY,WHETHER IN CONTRACT,STRICT LIABILITY,OR TORT(INCLUDING NEGLIGENCE 
  OR OTHERWISE)ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,EVEN IF ADVISED OF THE POSSIBILITY OF 
  SUCHDAMAGE.
************************************************************************************************/

/*
 * File: hesai_ros_driver_node.cu
 * Author: Zhang Yu <zhangyu@hesaitech.com>
 * Description: Hesai sdk node for GPU
 * Created on June 12, 2023, 10:46 AM
 */

#include "manager/node_manager.h"
#include <signal.h>

#include <iostream>
#include "Version.h"
#include <getopt.h>

#ifdef ROS_FOUND
#include <ros/ros.h>
#include <ros/package.h>
#elif ROS2_FOUND
#include <ament_index_cpp/get_package_share_directory.hpp>
#include <rclcpp/rclcpp.hpp>
#endif

#ifdef ROS2_FOUND
std::mutex g_mtx;
std::condition_variable g_cv;
#endif


static void sigHandler(int sig)
{
#ifdef ROS_FOUND
  ros::shutdown();
#elif ROS2_FOUND
  g_cv.notify_all();
#endif
}

int main(int argc, char** argv)
{
  std::cout << "-------- Hesai Lidar ROS V" << VERSION_MAJOR << "." << VERSION_MINOR << "." << VERSION_TINY << " --------" << std::endl;
  signal(SIGINT, sigHandler);  ///< bind ctrl+c signal with the sigHandler function

#ifdef ROS_FOUND
  ros::init(argc, argv, "hesai_ros_driver_node", ros::init_options::NoSigintHandler);
#elif ROS2_FOUND
  rclcpp::init(argc, argv);
#endif

  std::string config_path;

#ifdef RUN_IN_ROS_WORKSPACE
   config_path = ros::package::getPath("hesai_ros_driver");
#else
   config_path = ament_index_cpp::get_package_share_directory("hesai_ros_driver");
#endif

  config_path += "/config/config.yaml";
  struct option longopts[] = {
        {"config", optional_argument, NULL, 'c'},
        {0,0,0,0}
  };
  int opt;
  opterr = 0;
  while ((opt = getopt_long(argc, argv, "c:", longopts, nullptr)) != -1) {
    switch (opt) {
      case 'c':
        config_path = std::string(optarg);
        break;
      default:
        break;
    }
  }

#ifdef ROS_FOUND
  ros::NodeHandle priv_hh("~");
  std::string path;
  priv_hh.param("config_path", path, std::string(""));
  if (!path.empty())
  {
    config_path = path;
  }
#endif

  YAML::Node config;
  config = YAML::LoadFile(config_path);


  std::shared_ptr<NodeManager> demo_ptr = std::make_shared<NodeManager>();
  demo_ptr->Init(config);
  demo_ptr->Start();


#ifdef ROS_FOUND
  ros::MultiThreadedSpinner spinner(2); 
  spinner.spin();
#elif ROS2_FOUND
  std::unique_lock<std::mutex> lck(g_mtx);
  g_cv.wait(lck);
#endif

  return 0;
}
