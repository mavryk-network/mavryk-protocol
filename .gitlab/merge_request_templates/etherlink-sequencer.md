<!-- Etherlink sequencer merge request template. -->

# Context

# Manually testing the MR

# Checklist

- [ ] Document the interface of any function added or modified (see the [coding guidelines](https://protocol.mavryk.org/developer/guidelines.html))
- [ ] Document any change to the user interface, including configuration parameters (see [node configuration](https://protocol.mavryk.org/user/node-configuration.html))
- [ ] Provide automatic testing (see the [testing guide](https://protocol.mavryk.org/developer/testing.html)).
- [ ] For new features and bug fixes, add an item in the appropriate changelog (`docs/protocols/alpha.rst` for the protocol and the environment, `CHANGES.rst` at the root of the repository for everything else).
- [X] Select suitable reviewers using the `Reviewers` field below.
- [X] Select as `Assignee` the next person who should [take action on that MR](https://protocol.mavryk.org/developer/contributing.html#merge-request-assignees-field)

/assign @lthms @sribaroud @vch9 @picdc

/assign_reviewer @lthms @sribaroud @vch9 @picdc

/labels ~evm::sequencer

/milestone %"Etherlink: sequencers"
