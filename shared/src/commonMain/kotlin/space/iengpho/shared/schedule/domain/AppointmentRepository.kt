package space.iengpho.shared.schedule.domain

import space.iengpho.shared.schedule.model.Appointment

interface AppointmentRepository {
    fun fetchUpcoming(): List<Appointment>
}
