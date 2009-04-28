#ifndef PAES_ALLOCATION_HPP
#define PAES_ALLOCATION_HPP 1

#include <common.hpp>
#include <job.hpp>



namespace scheduler {
  /**
   * Encapsulates the volatile information of a schedule for a specific
   * job, i.e. queuetime and price.
   */
  class Allocation {
    public:
      typedef std::tr1::shared_ptr<Allocation> Ptr;
      Allocation (scheduler::Job::IDType jobID,
          double startTime,
          double queueTime,
          double finishTime,
          double price) :
        _jobID(jobID), _startTime(startTime), _queueTime(queueTime), 
        _finishTime(finishTime), _price(price) {};
      virtual ~Allocation() {};
      const scheduler::Job::IDType getJobID() { return _jobID; };
      const double getStartTime() { return _startTime; };
      void setStartTime(const double& startTime) { _startTime=startTime; };
      const double getQueueTime() { return _queueTime; };
      void setQueueTime(const double& queueTime) { _queueTime=queueTime; };
      const double getFinishTime() { return _finishTime; };
      void setFinishTime(const double& finishTime) { _finishTime=finishTime; };

      const std::string str() const;
      
    private:
      Allocation (const Allocation& original);
      Allocation& operator= (const Allocation& rhs);
      scheduler::Job::IDType _jobID;
      double _startTime;
      double _queueTime;
      double _finishTime;
      double _price;
  };

}


#endif /* PAES_ALLOCATION_HPP */

